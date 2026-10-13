require "rails_helper"

# The append-only scheme is the whole point of this table: replacing a photo
# must never destroy the one it replaced, because after cutover this table is
# the parish's only copy.
RSpec.describe LegacyAsset do
  describe ".current" do
    it "returns the newest published row for a name" do
      old = build_asset(human_name: "home-hero", bytes: "OLD", created_at: 2.days.ago)
      new = build_asset(human_name: "home-hero", bytes: "NEW", created_at: 1.hour.ago)

      expect(described_class.current("home-hero")).to eq(new)
      expect(old.reload).to be_persisted, "replacing a photo must not destroy the old one"
    end

    it "ignores drafts, so an unapproved photo never reaches the site" do
      live = build_asset(human_name: "home-hero", bytes: "LIVE", created_at: 2.days.ago)
      build_asset(human_name: "home-hero", bytes: "DRAFT", status: "draft",
                  created_at: 1.minute.ago)

      expect(described_class.current("home-hero")).to eq(live)
    end

    it "is nil for an unknown name rather than raising" do
      expect(described_class.current("no-such-photo")).to be_nil
    end

    # created_at has second resolution; two rows written in the same second
    # must still order deterministically or "newest wins" is a coin toss.
    it "breaks ties on id when timestamps match exactly" do
      at = Time.current
      build_asset(human_name: "tie", bytes: "FIRST", created_at: at)
      second = build_asset(human_name: "tie", bytes: "SECOND", created_at: at)

      expect(described_class.current("tie")).to eq(second)
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
