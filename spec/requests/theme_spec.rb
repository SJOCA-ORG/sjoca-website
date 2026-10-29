require "rails_helper"

# The stylesheet is a database row, served per revision. These specs exist
# because the same class of bug has now happened three times: a tool writing
# somewhere nothing reads, reporting success, and changing nothing.
RSpec.describe "The site's stylesheet and scripts" do
  let(:revision) { test_revision }

  before do
    build_page(slug: "home", title: "Home", nav_title: "Home")
    revision.theme_assets.find_or_initialize_by(name: "site.css").tap { |a| a.content = ":root { --maroon: #6D0606 }" }.save!
  end

  it "serves the stylesheet of the revision being rendered" do
    get theme_stylesheet_path(digest: ThemeAsset.digest_for(revision, "css"))

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.body).to include("--maroon: #6D0606")
  end

  it "is linked from the page, so the browser actually fetches it" do
    get "/"
    expect(response.body).to match(%r{/theme-[a-f0-9]+\.css})
  end

  # What set_styles writes, get_styles and the page must read. The tool wrote to
  # "overrides.css" while everything else read "site.css": it reported success
  # and changed nothing.
  it "serves what set_styles wrote" do
    Admin::Tools.new(Revision.open_sandbox)
    draft = Revision.drafts.first
    Admin::Tools.new(draft).call("set_styles", { "css" => ":root { --maroon: #8B1A1A }" })

    expect(ThemeAsset.css_for(draft)).to include("#8B1A1A")
    expect(Admin::Tools.new(draft).call("get_styles", {})[:css]).to include("#8B1A1A")
  end

  it "gives a changed stylesheet a different URL, so caches cannot serve the old one" do
    before_digest = ThemeAsset.digest_for(revision, "css")
    revision.theme_assets.find_by(name: "site.css").update!(content: ":root { --maroon: #8B1A1A }")

    expect(ThemeAsset.digest_for(revision, "css")).not_to eq(before_digest)
  end

  it "returns 304 rather than 500 on a conditional request" do
    path = theme_stylesheet_path(digest: ThemeAsset.digest_for(revision, "css"))
    get path
    etag = response.headers["ETag"]

    get path, headers: { "If-None-Match" => etag }
    expect(response).to have_http_status(:not_modified)
  end

  # The digest constraint is hex-only, so a made-up one does not even route --
  # which is the behaviour we want: no handler, no empty file, no 200.
  it "404s rather than serving an empty file when there are no scripts" do
    get "/theme-000000000000.js"
    expect(response).to have_http_status(:not_found)
  end

  it "serves JavaScript once set" do
    revision.theme_assets.find_or_initialize_by(name: "site.js").tap { |a| a.content = "console.log('hello')" }.save!

    get theme_javascript_path(digest: ThemeAsset.digest_for(revision, "js"))
    expect(response.body).to include("hello")
    expect(response.media_type).to eq("text/javascript")
  end
end
