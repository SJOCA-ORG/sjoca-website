require "rails_helper"

# The AI wrote templates blind -- it had no way to see its own output. These two
# tools are the cheap half of "look at the result": reading the rendered markup.
# The expensive half, seeing it at phone width, still needs a browser.
RSpec.describe "Seeing the rendered page" do
  let(:revision) { test_revision.tap { build_page(slug: "giving", title: "Giving", nav_title: "Giving") } }
  let(:draft)    { Revision.open_sandbox }
  let(:tools)    { Admin::Tools.new(draft) }
  let(:page)     { draft.pages.find_by(slug: "giving") }

  before do
    revision
    section = draft.pages.find_by(slug: "giving").sections.create!(revision: draft, style: "plain")
    section.blocks.create!(revision: draft, kind: "heading", content: "Financially Support")
  end

  describe "view_page" do
    it "returns what actually rendered" do
      result = tools.call("view_page", { "slug" => "giving" })
      expect(result[:html]).to include("Financially Support")
    end

    it "can return just the matching part, rather than the whole page" do
      result = tools.call("view_page", { "slug" => "giving", "find" => "heading" })
      expect(result[:html]).to include("b-heading")
      expect(result[:matching]).to eq("heading")
    end
  end

  describe "check_page" do
    it "passes a page that is fine" do
      result = tools.call("check_page", { "slug" => "giving" })
      expect(result[:ok]).to be(true)
      expect(result[:problems]).to be_empty
    end

    # The bug that prompted this: a template using a property that does not
    # exist renders empty and says nothing.
    it "catches a template using a property that does not exist" do
      draft.templates.find_by(name: "block/heading")
           .update!(source: %(<h2 class="b b-heading">{{ block.nonexistent }}</h2>))

      result = tools.call("check_page", { "slug" => "giving" })
      expect(result[:ok]).to be(false)
      expect(result[:problems].join).to match(/nonexistent/)
    end

    it "catches a half-written reference: a name with no version" do
      draft.pages.find_by(slug: "giving").sections.first
           .blocks.create!(revision: draft, kind: "image", asset_name: "photo-with-no-version")

      expect(tools.call("check_page", { "slug" => "giving" })[:problems].join)
        .to match(/no version/)
    end

    it "catches an image pointing at nothing" do
      draft.pages.find_by(slug: "giving").sections.first
           .blocks.create!(revision: draft, kind: "image",
                           asset_name: "missing-photo", asset_version: 1)
      draft.templates.find_by(name: "block/image")
           .update!(source: %(<img src="{{ block.photo.url }}" alt="x">))

      result = tools.call("check_page", { "slug" => "giving" })
      expect(result[:problems].join).to match(/no src/)
    end

    # Accessibility is kept OUT of problems: on the real site it produced 40
    # alt-text warnings across 11 pages, which would drown anything important
    # and teach the AI to ignore the whole list.
    it "reports missing alt text as a suggestion, not as breakage" do
      build_asset(human_name: "photo-without-alt", version: 1)
      draft.pages.find_by(slug: "giving").sections.first
           .blocks.create!(revision: draft, kind: "image",
                           asset_name: "photo-without-alt", asset_version: 1)

      result = tools.call("check_page", { "slug" => "giving" })
      expect(result[:ok]).to be(true)
      expect(result[:suggestions].join).to match(/alt text/)
    end
  end
end
