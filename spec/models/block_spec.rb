require "rails_helper"

RSpec.describe Block do
  # KINDS is the vocabulary an editor (and, in Phase 2, the AI) may use. It is
  # deliberately closed: an unknown kind has no renderer and would vanish.
  it "accepts every declared kind" do
    section = build_section(page: build_page)
    described_class::KINDS.each do |kind|
      expect(described_class.new(section: section, revision: section.revision, kind: kind))
        .to be_valid, "expected #{kind.inspect} to be a usable block kind"
    end
  end

  it "rejects a kind with no renderer behind it" do
    section = build_section(page: build_page)
    expect(described_class.new(section: section, revision: section.revision, kind: "carousel"))
      .not_to be_valid
  end

  describe "#asset" do
    # A reference is a pair. The block shows the version it points at, not
    # whatever happens to be newest -- which is what makes a rollback restore
    # the right picture.
    it "resolves exactly the version it points at" do
      old = build_asset(human_name: "choir", bytes: "OLD", version: 1)
      build_asset(human_name: "choir", bytes: "NEW", version: 2)
      block = build_block(section: build_section(page: build_page),
                          kind: "image", asset_name: "choir", asset_version: 1)

      expect(block.asset).to eq(old)
    end

    it "shows nothing when the version it points at is gone, rather than guessing" do
      build_asset(human_name: "choir", version: 2)
      block = build_block(section: build_section(page: build_page),
                          kind: "image", asset_name: "choir", asset_version: 1)

      expect(block.asset).to be_nil
    end

    it "is nil when no asset is named" do
      expect(build_block(section: build_section(page: build_page)).asset).to be_nil
    end
  end
end
