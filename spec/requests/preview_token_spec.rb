require "rails_helper"

# A signed link is how a headless browser -- and an Approver on their phone --
# sees a draft without logging in.
RSpec.describe "Signed preview links" do
  let(:live)  { test_revision.tap { build_page(slug: "home", title: "Home", nav_title: "Home") } }
  let(:draft) { live && Revision.open_sandbox }

  before { draft.pages.find_by(slug: "home").update!(title: "Draft title") }

  it "shows the draft to someone with the token" do
    get "/?preview=#{draft.preview_token}"
    expect(response.body).to include("Draft title")
  end

  it "shows the live site to someone without it" do
    get "/"
    expect(response.body).not_to include("Draft title")
  end

  it "ignores a forged token rather than trusting the id in it" do
    get "/?preview=#{draft.id}"
    expect(response.body).not_to include("Draft title")
  end

  it "ignores a tampered token" do
    get "/?preview=#{draft.preview_token.reverse}"
    expect(response.body).not_to include("Draft title")
  end

  # The preview linked a stylesheet URL with no token on it, so the browser
  # fetched it with no preview context and got the LIVE styles -- a preview
  # showing draft content with published appearance, which is worse than none
  # because it looks like it worked.
  it "carries the token through to the stylesheet" do
    get "/?preview=#{draft.preview_token}"
    expect(response.body).to match(%r{/theme-[a-f0-9]+\.css\?[^"]*preview=})
  end
end
