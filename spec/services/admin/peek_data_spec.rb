require "rails_helper"

# Written after watching a real turn fail. Asked to replace the ChurchTrac
# iframe with our own markup, the AI did everything right: it listed the data
# sources, read the Liquid guide, and fetched the embedded calendar page to find
# out where that page gets its events. peek_data showed it the first 1200
# characters of a 6278-character page. The address and its parameters were at
# character 4123. So it guessed, and spent the rest of its turn being refused
# with 403s by a server it was asking the wrong way.
#
# The tool was the problem, not the reasoning.
RSpec.describe "peek_data searching" do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:tools) { Admin::Tools.new(revision) }
  let(:url) { "https://example.com/widget" }

  # A page that embeds a feed, shaped like the real one: the interesting part
  # is well past any reasonable preview.
  let(:page_body) do
    "<html><head>#{'<meta filler>' * 200}</head><body>" \
      "<script>var cal = { eventSources: [{ url: \"/calendar_events\", " \
      "data: { source: 'public', church_ui: \"AE8E0B4D\" } }] };</script>" \
      "</body></html>"
  end

  before do
    FetchedPage.create!(key: FetchedPage.key_for(url), url: url, body: page_body,
                        content_type: "text/html", status: 200, fetched_at: Time.current)
    revision.data_sources.create!(name: "widget", urls: [url])
  end

  it "shows only the beginning without a search, and says so" do
    result = tools.call("peek_data", { "name" => "widget" })

    expect(result[:sample].length).to eq(Admin::Tools::PEEK_CHARS)
    expect(result[:sample]).not_to include("church_ui")
    expect(result[:note]).to include("find")
  end

  it "finds what is past the preview, with its surroundings" do
    result = tools.call("peek_data", { "name" => "widget", "find" => "eventSources" })

    expect(result[:found][:hits]).to eq(1)
    text = result[:found][:extracts].first[:text]
    expect(text).to include("/calendar_events")
    expect(text).to include("church_ui")
  end

  it "says plainly when the text is not there, rather than returning nothing" do
    result = tools.call("peek_data", { "name" => "widget", "find" => "rss" })

    expect(result[:found][:hits]).to eq(0)
    expect(result[:found][:note]).to include("does not appear")
  end

  it "caps how many matches come back, so a common word cannot flood the reply" do
    result = tools.call("peek_data", { "name" => "widget", "find" => "meta" })

    expect(result[:found][:hits]).to be <= Admin::Tools::FIND_HITS
  end
end
