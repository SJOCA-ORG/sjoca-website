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
    it "resolves the newest published version of its named image" do
      build_asset(human_name: "choir", bytes: "OLD", created_at: 2.days.ago)
      newest = build_asset(human_name: "choir", bytes: "NEW", created_at: 1.hour.ago)
      block = build_block(section: build_section(page: build_page),
                          kind: "image", asset_name: "choir")

      expect(block.asset).to eq(newest)
    end

    it "is nil when no asset is named" do
      expect(build_block(section: build_section(page: build_page)).asset).to be_nil
    end
  end
end
