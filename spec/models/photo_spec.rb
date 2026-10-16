require "rails_helper"

# The append-only scheme is the whole point of this table: replacing a photo
# must never destroy the one it replaced, because after cutover this table is
# the parish's only copy.
RSpec.describe Photo do
  # A reference is a PAIR -- slug and version -- so a page says exactly which
  # photograph it shows, and rolling back restores the picture with the words.
  describe ".find_version" do
    it "returns exactly the version asked for, not the newest" do
      old = build_asset(human_name: "home-hero", bytes: "OLD", version: 1)
      new = build_asset(human_name: "home-hero", bytes: "NEW", version: 2)

      expect(described_class.find_version("home-hero", 1)).to eq(old)
      expect(described_class.find_version("home-hero", 2)).to eq(new)
    end

    it "keeps every version, so last year's picture can be pointed at again" do
      build_asset(human_name: "christmas-pageant", bytes: "2025", version: 101)
      build_asset(human_name: "christmas-pageant", bytes: "2026", version: 222)

      expect(described_class.find_version("christmas-pageant", 101).data).to eq("2025")
      expect(described_class.versions_of("christmas-pageant").count).to eq(2)
    end

    it "ignores drafts, so an unapproved photo never reaches the site" do
      live = build_asset(human_name: "home-hero", bytes: "LIVE", version: 1)
      build_asset(human_name: "home-hero", bytes: "DRAFT", status: "draft", version: 2)

      expect(described_class.find_version("home-hero", 1)).to eq(live)
      expect(described_class.find_version("home-hero", 2)).to be_nil
    end

    it "is nil for an unknown name rather than raising" do
      expect(described_class.find_version("no-such-photo", 1)).to be_nil
    end

    it "is nil when the version does not exist, rather than falling back" do
      build_asset(human_name: "home-hero", version: 1)
      expect(described_class.find_version("home-hero", 99)).to be_nil
    end

    # Only for choosing which version to pin -- never for rendering.
    it "newest finds the highest version, for an editor picking one" do
      build_asset(human_name: "tie", bytes: "FIRST", version: 1)
      second = build_asset(human_name: "tie", bytes: "SECOND", version: 9)

      expect(described_class.newest("tie")).to eq(second)
    end
  end

  describe ".versions_of" do
    it "returns every version newest first, drafts included" do
      build_asset(human_name: "v", bytes: "A", created_at: 3.days.ago)
      build_asset(human_name: "v", bytes: "B", status: "draft", created_at: 2.days.ago)
      c = build_asset(human_name: "v", bytes: "C", created_at: 1.day.ago)
      build_asset(human_name: "other", bytes: "X")

      versions = described_class.versions_of("v")
      expect(versions.first).to eq(c)
      expect(versions.count).to eq(3)
    end
  end

  describe "validations" do
    it "rejects the same bytes twice under one name, so re-seeding cannot duplicate" do
      build_asset(human_name: "dup", bytes: "SAME")
      again = described_class.new(human_name: "dup", content_type: "image/png",
                                  data: "SAME", sha256: described_class.digest("SAME"),
                                  status: "published")

      expect(again).not_to be_valid
      expect(again.errors[:sha256]).to be_present
    end

    it "allows the same bytes under a different name" do
      build_asset(human_name: "a", bytes: "SAME")
      expect(described_class.new(human_name: "b", content_type: "image/png",
                                 data: "SAME", sha256: described_class.digest("SAME"),
                                 status: "published")).to be_valid
    end

    it "rejects an unknown status" do
      asset = described_class.new(human_name: "x", content_type: "image/png",
                                  data: "D", sha256: "abc", status: "whenever")
      expect(asset).not_to be_valid
    end
  end
end
