require "rails_helper"

# A whole website, written out as files and read back.
#
# The claim worth testing is not that files appeared. It is that a website
# exported and imported somewhere else IS THE SAME WEBSITE -- the same rendered
# pages, the same photographs down to their digests -- and that nothing about
# the account came with it.
#
# This is what a fresh deployment will do to get its starters, and what an
# organization will do to keep a copy of itself. If it is subtly lossy, the
# loss arrives as somebody's missing page months later.
RSpec.describe WebsiteArchive do
  let(:dir) { Rails.root.join("tmp/spec-archive-#{SecureRandom.hex(4)}") }
  after { FileUtils.rm_rf(dir) }

  let!(:source) do
    org = Organization.sole_tenant or raise "expected one organization"
    org.update!(canonical_url: "https://source.example", contact_email: "us@example.com",
                time_zone: "Europe/Berlin", locale: "en")
    org.add_host("source.example")

    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      revision.site_settings.create!(key: "name", value: "The Source")
      revision.site_settings.create!(key: "brand", value: "SRC")
      revision.templates.find_or_initialize_by(name: "footer").update!(source: "<footer>MINE</footer>")

      home = Page.create!(slug: "home", title: "Home", nav_title: "Home", revision: revision,
                          hero_heading: "A hero", hero_size: "tall")
      band = home.sections.create!(style: "light", revision: revision, position: 0)
      band.blocks.create!(kind: "heading", content: "A heading", revision: revision, position: 0)
      band.blocks.create!(kind: "text", content: "Some words", revision: revision, position: 1)
      Page.create!(slug: "about", title: "About", nav_title: "About", revision: revision, position: 1)

      bytes = "PNG-hero-bytes"
      photo = Photo.create!(human_name: "hero", content_type: "image/png", data: bytes,
                            byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                            status: "published", version: 1, alt_text: "A hero")
      photo.tags << Tag.create!(name: "general", label: "General")

      Lesson.create!(subject: "tone", body: "Write plainly, and never twice.")
      User.create!(email: "editor@source.example", password: "Passw0rd!", role: "superadmin")
    end
    org
  end

  describe "exporting" do
    before { described_class.export(source, to: dir) }

    it "writes files a person can read" do
      expect(dir.join("organization.yml")).to exist
      expect(dir.join("site.yml")).to exist
      expect(dir.join("photos.yml")).to exist
      expect(dir.join("photos/hero-v1.png")).to exist
    end

    it "names photographs so the folder can be browsed" do
      expect(dir.join("photos").children.map(&:basename).map(&:to_s)).to eq(["hero-v1.png"])
      expect(dir.join("photos/hero-v1.png").binread).to eq("PNG-hero-bytes")
    end

    it "carries the look and the words" do
      site = YAML.safe_load_file(dir.join("site.yml"))
      expect(site["templates"].map { |t| t["name"] }).to include("footer", "header", "page")
      expect(site["settings"]).to include({ "key" => "brand", "value" => "SRC" })
      expect(site["pages"].map { |p| p["slug"] }).to eq(%w[home about])
      expect(site["theme"].first["content"].length).to be > 10_000
      expect(site["lessons"].first["subject"]).to eq("tone")
    end

    # An archive is a website. An account is where it is installed.
    it "carries nothing about the account" do
      text = dir.children.select(&:file?).map(&:read).join
      expect(text).not_to include("source.example")
      expect(text).not_to include("us@example.com")
      expect(text).not_to include("editor@source.example")
    end

    it "is readable YAML rather than a blob" do
      expect(dir.join("site.yml").read).to start_with("title:")
    end

    # ActiveRecord#slice returns a HashWithIndifferentAccess, and YAML writes
    # one as "!ruby/hash:ActiveSupport::HashWithIndifferentAccess" with every
    # key tagged. That makes the file unreadable in a pull request -- which is
    # why these are directories and not tarballs -- and unloadable without
    # permitting arbitrary Ruby classes, which is why safe_load exists.
    it "contains no tagged Ruby objects" do
      dir.children.select(&:file?).each do |file|
        expect(file.read).not_to include("!ruby/"), "#{file.basename} has Ruby objects in it"
      end
    end
  end

  describe "importing" do
    it "refuses a folder that is not there" do
      expect { described_class.import(dir, slug: "nope") }.to raise_error(WebsiteArchive::Missing)
    end

    it "refuses a photograph that has been edited since it was exported" do
      described_class.export(source, to: dir)
      dir.join("photos/hero-v1.png").binwrite("something-else-entirely")

      expect { described_class.import(dir, slug: "tampered") }
        .to raise_error(WebsiteArchive::Missing, /does not match the digest/)
    end
  end

  # THE CLAIM. Everything above is detail.
  describe "the round trip", type: :request do
    it "produces the same website somewhere else" do
      described_class.export(source, to: dir)
      copy = described_class.import(dir, slug: "the-copy", name: "The Copy")
      copy.update!(canonical_url: "https://copy.example")
      copy.add_host("copy.example")

      %w[/ /about].each do |path|
        host! "source.example"
        get path
        original = normalise(response.body)

        host! "copy.example"
        get path
        restored = normalise(response.body)

        expect(restored).to eq(original), "#{path} came back different"
      end
    end

    it "brings every photograph, byte for byte" do
      described_class.export(source, to: dir)
      copy = described_class.import(dir, slug: "the-copy")

      mine   = Organization.acting_as(source) { Photo.order(:human_name).pluck(:human_name, :version, :sha256) }
      theirs = Organization.acting_as(copy)   { Photo.order(:human_name).pluck(:human_name, :version, :sha256) }

      expect(theirs).to eq(mine)
      expect(Organization.acting_as(copy) { Photo.first.data }).to eq("PNG-hero-bytes")
      expect(Organization.acting_as(copy) { Photo.first.tags.pluck(:name) }).to eq(["general"])
    end

    it "keeps the clock and the language" do
      described_class.export(source, to: dir)
      copy = described_class.import(dir, slug: "the-copy")

      expect(copy.time_zone).to eq("Europe/Berlin")
      expect(copy.locale).to eq("en")
    end

    it "brings no people and no hostnames" do
      described_class.export(source, to: dir)
      copy = described_class.import(dir, slug: "the-copy")

      expect(User.where(organization_id: copy.id)).to be_empty
      expect(copy.hosts).to be_empty
      expect(copy.contact_email).to be_nil
    end

    it "can be imported as a starter, and is then not a tenant" do
      described_class.export(source, to: dir)
      copy = described_class.import(dir, slug: "a-look", starter: true)

      expect(copy).to be_starter
      expect(Organization.tenants).not_to include(copy)
    end

    # Three things are normalised, and each is a fact about the copy rather
    # than a loss in it.
    #
    #   data-block, and any id="thing-123" -- a database id, which cannot be
    #   equal for two rows. Found by round-tripping the real site: the fixture
    #   here has no block that puts its id in an element id, so the first
    #   version of this normaliser passed while three real pages differed.
    #
    #   The canonical and og:url tags, which carry each organization's OWN
    #   address. An account's address does not travel with a website.
    #
    #   Embedded JSON from a data source, which is fetched when the page is
    #   rendered. The DEFINITION travels; what it returned a moment ago does not,
    #   and should not.
    def normalise(html)
      html.gsub(/data-block="\d+"/, 'data-block=""')
          .gsub(/id="([a-z-]+)-\d+"/, 'id="\\1"')
          .gsub(%r{<script type="application/json"[^>]*>.*?</script>}m, "<json/>")
          .gsub(%r{https?://(?:source|copy|target)\.example}, "https://site.example")
    end
  end
end
