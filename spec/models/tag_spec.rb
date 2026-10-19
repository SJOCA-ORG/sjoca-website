require "rails_helper"

# A menu that grows a new entry every time somebody mistypes is not a menu.
RSpec.describe Tag do
  it "treats the same tag typed differently as one tag" do
    first = described_class.for("Feast Days")

    expect(described_class.for("feast days")).to eq(first)
    expect(described_class.for("  FEAST-DAYS  ")).to eq(first)
    expect(described_class.count).to eq(1)
  end

  it "keeps the label as it was typed, for the menu" do
    expect(described_class.for("Feast Days").label).to eq("Feast Days")
    expect(described_class.for("Feast Days").name).to eq("feast-days")
  end

  it "is created by being used, since asking someone to define one first is how tagging stops" do
    expect { described_class.for("Pascha 2026") }.to change(described_class, :count).by(1)
  end

  it "refuses a label with nothing usable in it" do
    expect(described_class.for("   ")).to be_nil
    expect(described_class.for("!!!")).to be_nil
  end

  describe "on a photograph" do
    let(:photo) { Photo.create!(human_name: "test-photo", data: "x", content_type: "image/png", byte_size: 1, sha256: "a") }

    it "adds tags and says which were new" do
      added = photo.tag_with("clergy", "Feast Days")

      expect(added.map(&:label)).to contain_exactly("clergy", "Feast Days")
      expect(photo.tag_labels).to contain_exactly("clergy", "Feast Days")
    end

    it "does not fail on a tag the photograph already has" do
      photo.tag_with("clergy")

      expect(photo.tag_with("clergy")).to be_empty
      expect(photo.tag_labels).to eq(["clergy"])
    end

    it "removes a tag however it is typed" do
      photo.tag_with("Feast Days")
      photo.untag("feast days")

      expect(photo.tag_labels).to be_empty
    end

    it "finds photographs by tag, however the tag is typed" do
      photo.tag_with("Feast Days")

      expect(Photo.tagged("feast-days")).to include(photo)
    end

    # Removing a tag must never remove a photograph: this table is the parish's
    # only copy of these pictures.
    it "leaves the photograph alone when the tag is deleted" do
      photo.tag_with("clergy")
      Tag.find_by(name: "clergy").destroy

      expect(photo.reload).to be_persisted
      expect(photo.tag_labels).to be_empty
    end
  end
end
