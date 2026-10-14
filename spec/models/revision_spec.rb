require "rails_helper"

# The sandbox has one job: let someone change the site without the live site
# changing. These specs are that promise, written down.
RSpec.describe Revision do
  let!(:live) { test_revision }

  before do
    page = build_page(slug: "giving", title: "Giving", nav_title: "Giving")
    section = build_section(page: page)
    build_block(section: section, kind: "heading", content: "Financially Support")
  end

  describe ".open_sandbox" do
    it "copies the live content into a draft" do
      draft = described_class.open_sandbox

      expect(draft.state).to eq("draft")
      expect(draft.pages.count).to eq(live.pages.count)
      expect(draft.blocks.count).to eq(live.blocks.count)
      expect(draft.based_on).to eq(live)
    end

    it "copies deeply enough that the structure survives" do
      draft = described_class.open_sandbox
      page = draft.pages.find_by(slug: "giving")

      expect(page.sections.count).to eq(1)
      expect(page.sections.first.blocks.first.content).to eq("Financially Support")
    end

    # The entire point. If this fails, nothing else about the design matters.
    it "leaves the live site untouched when the draft is edited" do
      draft = described_class.open_sandbox
      draft.blocks.first.update!(content: "CHANGED IN DRAFT")

      expect(live.blocks.first.reload.content).to eq("Financially Support")
    end

    it "does not copy photographs — they are referenced by name and version themselves" do
      build_asset(human_name: "giving-photo")
      expect { described_class.open_sandbox }.not_to change(Photo, :count)
    end
  end

  describe "#publish!" do
    it "makes the draft live and supersedes what was there" do
      draft = described_class.open_sandbox
      draft.blocks.first.update!(content: "Approved wording")

      draft.publish!

      expect(described_class.live).to eq(draft)
      expect(live.reload.state).to eq("superseded")
      expect(described_class.live.blocks.first.content).to eq("Approved wording")
    end

    it "refuses to publish what is already live" do
      expect { live.publish! }.to raise_error(/already live/)
    end

    # Rollback is the same operation in the other direction -- any revision can
    # be made live again, repeatedly.
    it "can republish a superseded revision" do
      draft = described_class.open_sandbox
      draft.blocks.first.update!(content: "New")
      draft.publish!

      live.reload.publish!

      expect(described_class.live).to eq(live)
      expect(described_class.live.blocks.first.content).to eq("Financially Support")
    end
  end

  # A slug is unique within a revision and necessarily repeats across them --
  # that is what a revision is. The validation had to change with this feature.
  it "allows the same slug in two revisions" do
    draft = described_class.open_sandbox
    expect(draft.pages.find_by(slug: "giving")).to be_present
    expect(live.pages.find_by(slug: "giving")).to be_present
  end

  it "keeps a conversation per revision, so a session survives a reload" do
    draft = described_class.open_sandbox
    draft.messages.create!(role: "user", content: "move the photo up")
    draft.messages.create!(role: "assistant", content: "Moved it above the text.")

    expect(draft.reload.messages.map(&:role)).to eq(%w[user assistant])
  end
end
