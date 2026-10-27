require "rails_helper"

# Mitch: "I could see not wanting the bulletin on the website at all, but merely
# to have the bulletin use the AI for its weekly construction, using the parish
# styles, photo database, knowledge of the players... but never actually
# displaying on the website."
#
# A page can be made here and kept here. It is still written, previewed and
# exported; it is simply not a web page.
RSpec.describe "a page kept off the website", type: :request do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }

  def a_private_page
    revision.pages.create!(slug: "bulletins/2026-11-01", title: "Bulletin",
                           nav_title: "1 November", layout: "bulletin",
                           dated_on: Date.new(2026, 11, 1),
                           show_in_nav: false, on_website: false).tap do |page|
      section = page.sections.create!(revision: revision, position: 0, style: "plain")
      section.blocks.create!(revision: revision, kind: "heading", content: "Sunday 1 November")
    end
  end

  it "is not served to a visitor" do
    page = a_private_page
    revision.publish!

    get "/#{page.slug}"

    expect(response).to have_http_status(:not_found)
  end

  it "is still reachable through a signed preview link, because that is how it is written" do
    page = a_private_page

    get "/#{page.slug}?preview=#{revision.preview_token}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sunday 1 November")
  end

  it "is not offered to a search engine" do
    a_private_page
    revision.publish!

    get "/sitemap.xml"

    expect(response.body).not_to include("bulletins/2026-11-01")
  end

  it "cannot appear in the menu even if somebody asks for it" do
    revision.pages.create!(slug: "private-thing", title: "Private", nav_title: "Private",
                           show_in_nav: true, on_website: false)

    expect(revision.pages.in_nav.pluck(:slug)).not_to include("private-thing")
  end

  it "is still exported as a PDF and an email" do
    page = a_private_page
    expect(Page.off_website.pluck(:slug)).to include(page.slug)
    # The exports find a page by slug within a revision; they do not ask whether
    # it is public, and must not start.
    expect(revision.pages.find_by(slug: page.slug)).to eq(page)
  end

  it "an ordinary page is on the website without anybody saying so" do
    page = revision.pages.create!(slug: "ordinary", title: "O", nav_title: "O")

    expect(page.on_website).to be(true)
  end

  describe "the AI saying it" do
    it "makes one, and says plainly that it is not published" do
      result = Admin::Tools.new(revision).call("add_page", {
        "slug" => "letters/advent", "title" => "Advent letter", "nav_title" => "Advent",
        "on_website" => false
      })

      expect(revision.pages.find_by(slug: "letters/advent").on_website).to be(false)
      expect(result[:summary]).to match(/kept off the website/)
    end

    it "takes one off the website afterwards" do
      revision.pages.create!(slug: "oops", title: "Oops", nav_title: "Oops")
      Admin::Tools.new(revision).call("update_page", { "slug" => "oops", "on_website" => false })

      expect(revision.pages.find_by(slug: "oops").on_website).to be(false)
    end
  end
end

# The bulletin stopped being a thing Ruby knows about. What it knew is now a
# lesson -- the AI's own stored knowledge -- and the tools that encoded it are
# replaced by ones that know nothing about parishes.
RSpec.describe "no bulletin in the tool surface", type: :model do
  it "offers no bulletin-shaped tools" do
    expect(Admin::Tools.names.grep(/bulletin/)).to be_empty
  end

  it "offers the general ones instead" do
    expect(Admin::Tools.names).to include("add_page", "copy_page", "add_sections")
  end

  it "lets a lesson be filed under a subject nobody listed in Ruby" do
    lesson = Lesson.new(subject: "bulletin", body: "Something this parish does, at least ten characters.")

    expect(lesson).to be_valid
  end

  it "still refuses a subject that is not a word" do
    expect(Lesson.new(subject: "Not A Subject!", body: "ten characters at least")).not_to be_valid
  end

  # The whole point: copying last week onto this week is a general operation.
  it "copies one page onto another" do
    revision = Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox
    from = revision.pages.create!(slug: "a", title: "A", nav_title: "A")
    s = from.sections.create!(revision: revision, position: 0, style: "plain")
    s.blocks.create!(revision: revision, kind: "heading", content: "Last week")
    to = revision.pages.create!(slug: "b", title: "B", nav_title: "B")

    Admin::Tools.new(revision).call("copy_page", { "from" => "a", "to" => "b" })

    expect(to.reload.sections.count).to eq(1)
    expect(to.sections.first.blocks.first.content).to eq("Last week")
  end

  it "refuses to copy onto a page that already has something on it" do
    revision = Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox
    from = revision.pages.create!(slug: "a", title: "A", nav_title: "A")
    from.sections.create!(revision: revision, position: 0, style: "plain")
    to = revision.pages.create!(slug: "b", title: "B", nav_title: "B")
    to.sections.create!(revision: revision, position: 0, style: "plain")

    expect { Admin::Tools.new(revision).call("copy_page", { "from" => "a", "to" => "b" }) }
      .to raise_error(Admin::Tools::ToolError, /already has/)
  end
end
