require "rails_helper"

RSpec.describe "Rendering pages" do
  before do
    home = build_page(slug: "home", title: "Home", nav_title: "Home", position: 1)
    section = build_section(page: home, style: "plain")
    build_block(section: section, kind: "heading", content: "Service Times")
    build_block(section: section, kind: "text", content: "Vespers, Saturday 6pm")

    build_page(slug: "about-us", title: "About Us", nav_title: "About Us", position: 2)
    build_page(slug: "about-us/our-story", title: "Our Story", nav_title: "Our Story",
               parent_slug: "about-us", position: 1)
  end

  it "serves the home page at the root" do
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Service Times")
  end

  # Paths mirror the old Google Sites URLs exactly so existing links survive
  # cutover. A nested path must resolve, not 404.
  it "serves a nested page at its original path" do
    get "/about-us/our-story"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Our Story")
  end

  it "returns 404 with the navigation intact for an unknown page" do
    get "/no-such-page"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("About Us"), "the nav must render on the 404 page too"
  end

  it "renders the top-level navigation in position order" do
    get "/"
    expect(response.body.index("Home")).to be < response.body.index("About Us")
  end

  it "does not advertise a page hidden from the nav" do
    build_page(slug: "secret", title: "Secret", nav_title: "Secret", show_in_nav: false)
    get "/"
    expect(response.body).not_to include(">Secret<")
  end
end
