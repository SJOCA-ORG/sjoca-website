require "rails_helper"

# "How do I get these formats in the future?" -- the exports began life as
# buttons in the editing pane, which answered that only while you happened to
# be editing the draft a bulletin was made in. A bulletin is wanted again
# later: reprinted, re-sent, checked against what went out.
RSpec.describe "bulletins", type: :request do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }

  def a_bulletin(on: Date.new(2026, 10, 26))
    page = revision.pages.create!(
      slug: "bulletins/#{on.iso8601}", title: "Bulletin", nav_title: on.to_s,
      layout: "bulletin", dated_on: on, show_in_nav: false
    )
    section = page.sections.create!(revision: revision, position: 0, style: "plain")
    section.blocks.create!(revision: revision, kind: "heading", content: "Saint John the Baptist")
    page
  end

  describe "the list" do
    it "shows a bulletin with both downloads" do
      a_bulletin

      get "/admin/bulletins"

      expect(response.body).to include("26 October 2026")
      expect(response.body).to include("bulletin/pdf")
      expect(response.body).to include("bulletin/email")
    end

    # "I downloaded it" and "the parish can see it" are different things.
    it "says whether each one is published or still a draft" do
      a_bulletin

      get "/admin/bulletins"

      expect(response.body).to include("draft")
    end

    it "says so plainly when there are none" do
      get "/admin/bulletins"

      expect(response.body).to include("None yet")
    end

    it "does not list ordinary pages" do
      get "/admin/bulletins"

      expect(response.body).not_to include("/home")
    end
  end

  describe "the email" do
    it "comes out as a whole HTML document" do
      page = a_bulletin

      get "/admin/revisions/#{revision.id}/bulletin/email", params: { slug: page.slug }

      expect(response.content_type).to start_with("text/html")
      expect(response.body).to include("<!DOCTYPE html>")
      expect(response.body).to include("Saint John the Baptist")
    end

    it "is named after the day it is for" do
      page = a_bulletin

      get "/admin/revisions/#{revision.id}/bulletin/email", params: { slug: page.slug }

      expect(response.headers["Content-Disposition"]).to include("bulletin-2026-10-26.html")
    end

    # Mail clients throw away <style> blocks, so a class resolves to nothing.
    it "carries its styles inline and uses no classes" do
      page = a_bulletin

      get "/admin/revisions/#{revision.id}/bulletin/email", params: { slug: page.slug }

      expect(response.body.scan(/style="/).size).to be > 5
      expect(response.body).not_to match(/class="/)
    end

    # A link in an email has nothing to be relative to.
    it "writes absolute addresses" do
      page = a_bulletin
      page.sections.first.blocks.create!(
        revision: revision, kind: "button", content: "Give", url: "https://example.com/give"
      )

      get "/admin/revisions/#{revision.id}/bulletin/email", params: { slug: page.slug }

      expect(response.body).to include("https://example.com/give")
    end

    it "refuses a page that is not there" do
      get "/admin/revisions/#{revision.id}/bulletin/email", params: { slug: "nope" }

      expect(response).to have_http_status(:not_found)
    end
  end
end

# The admin's list is of pages with a layout of their own, not of bulletins.
# A parish that writes a "newsletter" template should see newsletters here
# without anybody changing a line of Ruby.
RSpec.describe "the printable pages list", type: :request do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }

  it "shows a page whose layout nobody wrote code for" do
    revision.templates.create!(name: "newsletter", source: "<main>{{ page.title }}</main>")
    revision.pages.create!(slug: "newsletters/michaelmas", title: "Michaelmas",
                           nav_title: "Michaelmas", layout: "newsletter",
                           dated_on: Date.new(2026, 9, 29), show_in_nav: false)

    get "/admin/bulletins"

    expect(response).to have_http_status(:ok)
    # The list shows a dated page by its date, and counts it by its own layout
    # name -- "1 newsletter", not "1 bulletin".
    expect(response.body).to include("29 September 2026")
    expect(response.body).to match(/1 newsletter/i)
  end
end
