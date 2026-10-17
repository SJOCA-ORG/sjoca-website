require "rails_helper"

RSpec.describe DataSource do
  let(:revision) { test_revision }

  def source(**attrs)
    revision.data_sources.new({ name: "calendar", urls: ["https://example.com/feed"],
                                refresh_minutes: 60 }.merge(attrs))
  end

  describe "validation" do
    it "accepts a plain name" do
      expect(source).to be_valid
    end

    # The name becomes an id in the page, so it has to be usable as one.
    it "refuses a name that would not work as an element id" do
      expect(source(name: "My Calendar!")).not_to be_valid
      expect(source(name: "Calendar")).not_to be_valid
      expect(source(name: "-leading")).not_to be_valid
    end

    it "refuses http, and anything that is not a web address" do
      expect(source(urls: ["http://example.com/feed"])).not_to be_valid
      expect(source(urls: ["ftp://example.com/feed"])).not_to be_valid
      expect(source(urls: ["not a url"])).not_to be_valid
    end

    it "needs at least one address" do
      expect(source(urls: [])).not_to be_valid
    end

    it "refuses a refresh so short it would hammer the source" do
      expect(source(refresh_minutes: 1)).not_to be_valid
    end

    it "is unique per revision by name" do
      source.save!
      expect(source).not_to be_valid
    end
  end

  it "reports its domains, for the approval screen" do
    s = source(urls: ["https://a.example.com/x", "https://b.example.com/y",
                      "https://a.example.com/z"])
    expect(s.domains).to eq(%w[a.example.com b.example.com])
  end

  describe "the payload handed to the page" do
    def cache(url, body, type = "application/json")
      FetchedPage.create!(key: FetchedPage.key_for(url), url: url, body: body,
                          content_type: type, status: 200, fetched_at: Time.current)
    end

    it "passes JSON through" do
      cache("https://example.com/feed", '[{"title":"Vespers"}]')
      expect(JSON.parse(source.payload)).to eq([{ "title" => "Vespers" }])
    end

    # A page of HTML is not JSON, but the payload must still be valid JSON or
    # the script tag it sits in cannot be parsed. So it becomes a JSON string:
    # one JSON.parse either way.
    it "turns a page that is not JSON into a JSON string" do
      cache("https://example.com/feed", "<html>Vespers</html>", "text/html")
      expect(JSON.parse(source.payload)).to eq("<html>Vespers</html>")
    end

    it "gives an array when there are several addresses, so a date range is one source" do
      cache("https://example.com/a", '{"day":1}')
      cache("https://example.com/b", '{"day":2}')
      s = source(urls: ["https://example.com/a", "https://example.com/b"])

      expect(JSON.parse(s.payload).map { |e| e["body"] }).to eq([{ "day" => 1 }, { "day" => 2 }])
    end
  end

  describe "caching" do
    it "serves what it already holds rather than fetching again" do
      url = "https://example.com/feed"
      FetchedPage.create!(key: FetchedPage.key_for(url), url: url, body: "{}",
                          content_type: "application/json", fetched_at: 2.minutes.ago)
      expect(Site::OutboundFetch).not_to receive(:call)

      FetchedPage.for(url, max_age_minutes: 60)
    end

    # A parish site showing last night's calendar is fine. One showing an error
    # because ChurchTrac is briefly down is not.
    it "serves a stale copy when the source cannot be reached" do
      url = "https://example.com/feed"
      FetchedPage.create!(key: FetchedPage.key_for(url), url: url, body: '{"old":true}',
                          content_type: "application/json", fetched_at: 3.days.ago)
      allow(Site::OutboundFetch).to receive(:call)
        .and_raise(Site::OutboundFetch::Refused, "example.com did not answer")

      row = FetchedPage.for(url, max_age_minutes: 60)
      expect(row.body).to eq('{"old":true}')
      expect(row).to be_stale
    end

    it "raises when it cannot be reached and holds nothing" do
      allow(Site::OutboundFetch).to receive(:call)
        .and_raise(Site::OutboundFetch::Refused, "nope")

      expect { FetchedPage.for("https://example.com/new") }
        .to raise_error(Site::OutboundFetch::Refused)
    end
  end
end
