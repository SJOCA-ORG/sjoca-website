require "rails_helper"

RSpec.describe DataDrop do
  let(:revision) { test_revision }
  let(:url) { "https://example.com/feed" }

  before do
    Current.revision = revision
    FetchedPage.create!(key: FetchedPage.key_for(url), url: url,
                        body: '[{"title":"Vespers"}]',
                        content_type: "application/json", fetched_at: Time.current)
    revision.data_sources.create!(name: "calendar", urls: [url], refresh_minutes: 60)
  end

  def render(source) = Liquid::Template.parse(source).render("site" => SiteDrop.new)

  # Liquid collects a drop's complaint into template.errors rather than letting
  # it escape, so an assertion about loudness has to look there.
  def render_with_errors(source)
    t = Liquid::Template.parse(source)
    [t.render("site" => SiteDrop.new), t.errors.map(&:message).join(" ")]
  end

  it "writes the data into the page as a JSON island" do
    out = render("{{ site.data.calendar.json_tag }}")

    expect(out).to start_with('<script type="application/json" id="data-calendar">')
    expect(out).to end_with("</script>")
    expect(JSON.parse(out[/>(.*)<\/script>/m, 1])).to eq([{ "title" => "Vespers" }])
  end

  it "can be reached by a name with a hyphen in it" do
    revision.data_sources.create!(name: "daily-readings", urls: [url])
    expect(render('{{ site.data["daily-readings"].id }}')).to eq("data-daily-readings")
  end

  # The payload is fetched from somewhere else, so it must not be able to close
  # the element it sits in. This is the injection that matters here.
  it "cannot break out of the script tag" do
    evil = "https://example.com/evil"
    FetchedPage.create!(key: FetchedPage.key_for(evil), url: evil,
                        content_type: "text/html", fetched_at: Time.current,
                        body: '</script><script>alert("xss")</script>')
    revision.data_sources.create!(name: "nasty", urls: [evil])

    out = render("{{ site.data.nasty.json_tag }}")

    expect(out.scan("<script").size).to eq(1)
    expect(out).not_to include("</script><script>")
    expect(JSON.parse(out[/>(.*)<\/script>/m, 1])).to include("alert")
  end

  # Loud in a draft, silent on the live site: the same bargain every other drop
  # makes. A missing data source is a template bug the editor should hear about
  # while editing, and never a 500 for a visitor.
  it "says what it has when asked for something that is not set up, while editing" do
    build_page
    Current.revision = Revision.open_sandbox

    _, errors = render_with_errors("{{ site.data.nonexistent.json_tag }}")

    expect(errors).to match(/no "nonexistent"/)
  end

  it "stays silent about a missing data source on the live site" do
    out, errors = render_with_errors("{{ site.data.nonexistent.json_tag }}")

    expect(out).to eq("")
    expect(errors).to be_empty
  end

  it "reports its state for a template that wants to say something went wrong" do
    expect(render("{{ site.data.calendar.ok }}")).to eq("true")
    expect(render("{{ site.data.calendar.bytes }}")).to eq("21")
  end
end
