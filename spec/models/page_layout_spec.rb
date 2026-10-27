require "rails_helper"

# A layout used to be one of exactly two words, listed in Ruby. A parish wanting
# a quarterly newsletter therefore needed a developer. It needs a template.
RSpec.describe "what a page's layout is", type: :model do
  let(:revision) { Revision.tap { build_page }.open_sandbox }

  def page_with(layout)
    Page.create!(revision: revision, slug: "x-#{layout}-#{rand(9999)}",
                 title: "X", nav_title: "X", layout: layout)
  end

  it "accepts a layout nobody has written code for" do
    expect { page_with("newsletter") }.not_to raise_error
    expect(Page.laid_out_as("newsletter").count).to eq(1)
  end

  it "still accepts the two that always worked" do
    expect { page_with("page") }.not_to raise_error
    expect { page_with("bulletin") }.not_to raise_error
  end

  it "refuses a name that could not be a template" do
    bad = Page.new(revision: revision, slug: "y", title: "Y", nav_title: "Y",
                   layout: "Not A Template!")
    expect(bad).not_to be_valid
    expect(bad.errors[:layout].first).to match(/names a template/)
  end

  # It must be possible to make the page before the template exists -- the AI
  # does one then the other, and the renderer falls back to "page" meanwhile.
  it "does not require the template to exist yet" do
    expect(revision.templates.exists?(name: "newsletter")).to be(false)
    expect { page_with("newsletter") }.not_to raise_error
  end

  it "renders through the template its layout names, once there is one" do
    revision.templates.create!(name: "newsletter", source: "<main>NEWSLETTER</main>")
    page = page_with("newsletter")

    expect(Site::PageRenderer.new(revision).template_for(page)).to eq("newsletter")
  end

  it "falls back to the ordinary page template when there is none" do
    page = page_with("gazette")

    expect(Site::PageRenderer.new(revision).template_for(page)).to eq("page")
  end

  describe "finding them" do
    before do
      page_with("page")
      page_with("bulletin")
      page_with("newsletter")
    end

    it "separates ordinary pages from the rest" do
      expect(Page.ordinary.count).to be >= 1
      expect(Page.special.pluck(:layout)).to contain_exactly("bulletin", "newsletter")
    end

    it "keeps the bulletin shorthand working" do
      expect(Page.bulletins.pluck(:layout)).to eq(["bulletin"])
    end
  end
end
