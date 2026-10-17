require "rails_helper"

# The preview flag is sticky on purpose: an editor browses the whole site and
# simply sees their draft. That turned into a trap. The pin survived the draft
# being discarded, so the browser went on rendering a dead revision and the live
# site was unreachable from that browser -- while looking like an ordinary bug,
# because the dead revision still held an old template whose empty state read
# "The calendar is being updated."
#
# It cost an hour of looking at the wrong thing.
RSpec.describe "a stale preview pin", type: :request do
  before { build_page(slug: "home", title: "Home") }

  def pin(revision) = get("/admin/revisions/#{revision.id}/preview")

  it "renders the draft while it is a draft" do
    draft = Revision.open_sandbox
    draft.pages.find_by(slug: "home").update!(title: "Draft title")
    pin(draft)

    get "/"
    expect(response.body).to include("Draft title")
  end

  it "falls back to the live site once the draft is discarded" do
    draft = Revision.open_sandbox
    draft.pages.find_by(slug: "home").update!(title: "Draft title")
    pin(draft)
    draft.update!(state: "discarded")

    get "/"
    expect(response.body).not_to include("Draft title")
    expect(response).to have_http_status(:ok)
  end

  it "clears the pin rather than re-checking it on every request" do
    draft = Revision.open_sandbox
    pin(draft)
    draft.update!(state: "discarded")

    get "/"
    expect(session[:preview_revision_id]).to be_nil
  end

  it "falls back once the draft is published, so nobody previews the live site" do
    draft = Revision.open_sandbox
    pin(draft)
    draft.publish!

    get "/"
    expect(session[:preview_revision_id]).to be_nil
  end

  # Same hole, other door: a signed link to a revision that is no longer a draft.
  it "refuses a signed preview token for a discarded revision" do
    draft = Revision.open_sandbox
    draft.pages.find_by(slug: "home").update!(title: "Draft title")
    token = draft.preview_token
    draft.update!(state: "discarded")

    get "/?preview=#{token}"
    expect(response.body).not_to include("Draft title")
  end
end

# The preview pane lets you click around the draft. Links in a page are
# ordinary ("/about-us"), so without help a click lands on the LIVE site --
# which looks like the draft silently losing your change.
RSpec.describe "clicking around inside the preview pane", type: :request do
  before { build_page(slug: "home", title: "Home") }

  let(:draft) { Revision.open_sandbox }

  it "carries the token through links, but only in the pane" do
    get "/?preview=#{draft.preview_token}&bare=1"
    expect(response.body).to include('searchParams.set("preview"')
  end

  it "adds nothing at all to the live site" do
    get "/"
    expect(response.body).not_to include('searchParams.set("preview"')
  end

  it "adds nothing to an ordinary preview opened in a real tab" do
    get "/?preview=#{draft.preview_token}"
    expect(response.body).not_to include('searchParams.set("preview"')
  end

  it "keeps the draft banner in a real tab and drops it in the pane" do
    get "/?preview=#{draft.preview_token}"
    expect(response.body).to include("You are looking at a draft")

    get "/?preview=#{draft.preview_token}&bare=1"
    expect(response.body).not_to include("You are looking at a draft")
  end

  it "ignores bare on the live site, so nobody can hide the banner with a query string" do
    get "/?bare=1"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('searchParams.set("preview"')
  end
end
