require "rails_helper"

# These specs are the firewall, written down. The rule is not "the AI may not
# run programs" -- it is that it may run three known programs, with validated
# arguments, on files it cannot name, in a directory it cannot leave.
RSpec.describe Admin::ImageTools do
  subject(:tools) { described_class.new(test_revision) }

  # A genuine PNG, generated rather than pasted -- a hand-typed base64 blob
  # turned out to be corrupt and failed the specs for the wrong reason.
  let(:png) { Rails.root.join("spec/fixtures/sample.png").binread }

  before { build_asset(human_name: "sample", bytes: png, content_type: "image/png") }

  describe "it works at all" do
    it "resizes and stores the result as a new photograph" do
      result = tools.resize(name: "sample", width: 1, as: "sample-small")

      expect(result[:ok]).to be(true)
      expect(Photo.newest("sample-small")).to be_present
    end

    it "never overwrites the original, so a bad crop is undone by republishing" do
      original = Photo.newest("sample").data
      tools.grayscale(name: "sample", as: "sample-grey")

      expect(Photo.newest("sample").data).to eq(original)
    end

    it "reports dimensions without changing anything" do
      expect(tools.describe(name: "sample")).to include(width: 8, height: 8)
    end
  end

  describe "1. no shell" do
    # Processes are spawned with an argv array. There is no shell, so these are
    # not escaping tests -- they are proof that the input never reaches one.
    it "treats a shell metacharacter in a name as a name, not a command" do
      expect { tools.resize(name: "sample; rm -rf /", width: 1, as: "x") }
        .to raise_error(described_class::ToolError, /no photograph called/)
    end

    it "refuses an output name containing shell characters" do
      expect { tools.resize(name: "sample", width: 1, as: "out; touch /tmp/pwned") }
        .to raise_error(described_class::ToolError, /not a usable name/)
      expect(File).not_to exist("/tmp/pwned")
    end

    it "refuses a non-numeric dimension rather than passing it through" do
      expect { tools.crop(name: "sample", x: 0, y: 0, width: "1 -write /tmp/evil.png", height: 1, as: "x") }
        .to raise_error(described_class::ToolError, /not a whole number/)
      expect(File).not_to exist("/tmp/evil.png")
    end
  end

  describe "2. no paths" do
    it "cannot name a file on disk, only a photograph" do
      expect { tools.resize(name: "/etc/passwd", width: 1, as: "x") }
        .to raise_error(described_class::ToolError, /no photograph called/)
    end

    it "cannot traverse out of the working directory" do
      expect { tools.resize(name: "../../../../etc/hosts", width: 1, as: "x") }
        .to raise_error(described_class::ToolError, /no photograph called/)
    end

    it "refuses an output name that looks like a path" do
      expect { tools.grayscale(name: "sample", as: "../../escape") }
        .to raise_error(described_class::ToolError, /not a usable name/)
    end
  end

  describe "3. no network" do
    # ImageMagick will read https:// as an input filename. config/imagemagick/
    # policy.xml refuses that; this proves the policy is actually in force.
    it "refuses a URL as an input" do
      expect { tools.resize(name: "https://example.com/x.png", width: 1, as: "x") }
        .to raise_error(described_class::ToolError, /no photograph called/)
    end

    it "has the URL coders disabled in the policy it runs under" do
      out, = Open3.capture2e(
        { "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s },
        "magick", "https://example.com/x.png", "/tmp/should-not-exist.png"
      )
      expect(out).to match(/not authorized by the security policy/i)
      expect(File).not_to exist("/tmp/should-not-exist.png")
    end
  end

  describe "4. no runaway" do
    it "refuses a format outside the allowlist" do
      expect { tools.convert(name: "sample", format: "msl", as: "x") }
        .to raise_error(described_class::ToolError, /format must be one of/)
    end

    it "refuses a gravity outside the allowlist" do
      expect { tools.composite(base: "sample", overlay: "sample", gravity: "nowhere", as: "x") }
        .to raise_error(described_class::ToolError, /gravity must be one of/)
    end

    it "clamps a feather radius rather than passing a huge one through" do
      expect { tools.feather_edges(name: "sample", radius: 99_999, as: "sample-feathered") }
        .not_to raise_error
    end
  end
end
