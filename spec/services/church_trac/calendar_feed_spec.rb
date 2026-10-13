require "rails_helper"

# These specs exist because of a day lost to a silent failure. Requesting the
# feed with a HeadlessChrome User-Agent gets 302'd to ChurchTrac's marketing
# homepage, which returns ~115KB of HTML. Parsed leniently that is "0 events",
# and 0 events looks exactly like a parish with nothing scheduled.
RSpec.describe ChurchTrac::CalendarFeed do
  let(:config) { Rails.application.config.church_trac }
  let(:endpoint) { %r{#{Regexp.escape(config.base_url)}/calendar_events} }
  let(:from) { Date.new(2026, 10, 1) }
  let(:to)   { Date.new(2026, 10, 31) }

  def stub_feed(body:, status: 200, headers: { "Content-Type" => "application/json" })
    stub_request(:get, endpoint).to_return(status: status, body: body, headers: headers)
  end

  describe "refusing to mistake failure for emptiness" do
    it "raises when handed HTML instead of JSON" do
      stub_feed(body: "<!doctype html><html>marketing site</html>",
                headers: { "Content-Type" => "text/html" })

      expect { described_class.new.events(from: from, to: to) }
        .to raise_error(described_class::FeedError, /not JSON/)
    end

    it "raises when handed a JSON object rather than the expected array" do
      stub_feed(body: { error: "nope" }.to_json)

      expect { described_class.new.events(from: from, to: to) }
        .to raise_error(described_class::FeedError, /Expected a JSON array/)
    end

    it "raises on an HTTP error rather than returning nothing" do
      stub_feed(body: "", status: 403)

      expect { described_class.new.events(from: from, to: to) }
        .to raise_error(described_class::FeedError, /403/)
    end

    # The difference that matters: an empty array really is "nothing scheduled",
    # and must not raise. Only a malformed response is a failure.
    it "returns empty for a genuinely empty array" do
      stub_feed(body: "[]")
      expect(described_class.new.events(from: from, to: to)).to eq([])
    end
  end

  describe "the request itself" do
    it "presents a browser User-Agent, without which the load balancer 403s" do
      stub_feed(body: "[]")
      described_class.new.events(from: from, to: to)

      expect(a_request(:get, endpoint).with(headers: {
        "User-Agent" => described_class::USER_AGENT
      })).to have_been_made
    end

    it "does not claim to be headless, which triggers the redirect" do
      expect(described_class::USER_AGENT).not_to match(/headless/i)
    end
  end

  describe "normalising what comes back" do
    around { |ex| Time.use_zone("America/New_York") { ex.run } }

    let(:raw) do
      [{ "id" => "1", "title" => "  Vespers  ", "start" => "2026-10-17 18:00:00",
         "end" => "2026-10-17 19:00:00", "allDay" => false, "recurring" => "1",
         "location" => "4100 Goodman St N", "UID" => "abc" }]
    end

    it "parses times as parish-local, since the feed carries no zone" do
      stub_feed(body: raw.to_json)
      event = described_class.new.events(from: from, to: to).first

      expect(event[:starts_at]).to eq(Time.zone.parse("2026-10-17 18:00"))
      expect(event[:starts_at].time_zone.name).to eq("America/New_York")
    end

    it "strips whitespace from titles" do
      stub_feed(body: raw.to_json)
      expect(described_class.new.events(from: from, to: to).first[:title]).to eq("Vespers")
    end

    it "substitutes a placeholder rather than an empty title" do
      stub_feed(body: [raw.first.merge("title" => "   ")].to_json)
      expect(described_class.new.events(from: from, to: to).first[:title]).to eq("(untitled)")
    end

    it "treats recurring '0' as not recurring" do
      stub_feed(body: [raw.first.merge("recurring" => "0")].to_json)
      expect(described_class.new.events(from: from, to: to).first[:recurring]).to be(false)
    end

    it "skips an event with no parseable start" do
      stub_feed(body: [raw.first.merge("start" => nil)].to_json)
      expect(described_class.new.events(from: from, to: to)).to be_empty
    end
  end

  # ChurchTrac treats start/end as a hint, not a filter: asking for October
  # returns events from months either side. The caller must narrow it.
  describe "windowing" do
    around { |ex| Time.use_zone("America/New_York") { ex.run } }

    it "discards events outside the requested window" do
      stub_feed(body: [
        { "id" => "1", "title" => "September", "start" => "2026-09-20 18:00:00" },
        { "id" => "2", "title" => "October",   "start" => "2026-10-17 18:00:00" },
        { "id" => "3", "title" => "November",  "start" => "2026-11-04 18:00:00" }
      ].to_json)

      titles = described_class.new.events(from: from, to: to).map { |e| e[:title] }
      expect(titles).to eq(["October"])
    end

    it "includes events on the window's final day" do
      stub_feed(body: [{ "id" => "1", "title" => "Last day",
                         "start" => "2026-10-31 18:00:00" }].to_json)
      expect(described_class.new.events(from: from, to: to).size).to eq(1)
    end

    it "returns events in start order whatever order they arrive in" do
      stub_feed(body: [
        { "id" => "2", "title" => "Later",  "start" => "2026-10-20 18:00:00" },
        { "id" => "1", "title" => "Sooner", "start" => "2026-10-05 18:00:00" }
      ].to_json)

      expect(described_class.new.events(from: from, to: to).map { |e| e[:title] })
        .to eq(%w[Sooner Later])
    end
  end
end
