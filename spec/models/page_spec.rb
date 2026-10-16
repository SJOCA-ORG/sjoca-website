require "rails_helper"

RSpec.describe Page do
  describe ".find_by_path!" do
    # Paths mirror the old Google Sites URLs exactly, so links already out in
    # the world keep working after cutover. A leading slash must not break that.
    it "finds a nested page with or without a leading slash" do
      page = build_page(slug: "about-us/our-story", title: "Our Story", nav_title: "Our Story")

      expect(described_class.find_by_path!("about-us/our-story")).to eq(page)
      expect(described_class.find_by_path!("/about-us/our-story")).to eq(page)
    end

    it "raises for an unknown path so the controller can 404" do
      expect { described_class.find_by_path!("nope") }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#children" do
    it "returns navigable children in position order" do
      build_page(slug: "about-us", title: "About", nav_title: "About Us")
      second = build_page(slug: "about-us/choir", title: "Choir", nav_title: "Choir",
                          parent_slug: "about-us", position: 2)
      first  = build_page(slug: "about-us/our-story", title: "Story", nav_title: "Our Story",
                          parent_slug: "about-us", position: 1)

      expect(described_class.find_by!(slug: "about-us").children.to_a).to eq([first, second])
    end

    it "omits children hidden from the nav" do
      build_page(slug: "about-us", title: "About", nav_title: "About Us")
      build_page(slug: "about-us/secret", title: "Secret", nav_title: "Secret",
                 parent_slug: "about-us", show_in_nav: false)

      expect(described_class.find_by!(slug: "about-us").children).to be_empty
    end
  end

  describe "#hero_asset" do
    # "Swap a photo without touching any page" is deliberately gone. It was
    # invisible: you could not tell from a page which picture it would show, and
    # a swap changed pages nobody had edited. Replacing is now an edit.
    it "keeps showing the version it points at when a newer one is added" do
      first = build_asset(human_name: "home-hero", bytes: "FIRST", version: 1)
      page  = build_page(hero_asset_name: "home-hero", hero_asset_version: 1)
      build_asset(human_name: "home-hero", bytes: "SECOND", version: 2)

      expect(page.hero_asset).to eq(first)
    end

    it "is nil when the page names no hero" do
      expect(build_page.hero_asset).to be_nil
    end

    it "is nil when the named asset does not exist, rather than raising" do
      expect(build_page(hero_asset_name: "missing", hero_asset_version: 1).hero_asset).to be_nil
    end
  end

  it "requires a unique slug" do
    build_page(slug: "home")
    expect(described_class.new(slug: "home", title: "T", nav_title: "N")).not_to be_valid
  end
end
