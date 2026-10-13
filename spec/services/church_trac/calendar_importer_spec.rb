require "rails_helper"

# The importer's defining property is that it fails *closed*. A broken feed and
# a quiet parish look identical from the front of the site, so the mirror must
# never empty itself on a bad day and call it success.
RSpec.describe ChurchTrac::CalendarImporter do
  let(:config) { Rails.application.config.church_trac }
  let(:feed)   { instance_double(ChurchTrac::CalendarFeed) }

  def attrs(title:, starts_at:, id: "1", **extra)
    { churchtrac_id: id, uid: "u#{id}", title: title, starts_at: starts_at,
      ends_at: nil, all_day: false, recurring: true, location: nil, notes: nil,
      calendar_name: nil }.merge(extra)
  end

  def in_window = 2.days.from_now.change(usec: 0)

  describe "refusing to prune" do
    it "changes nothing when the feed comes back empty" do
      existing = build_event(title: "Vespers", starts_at: in_window, churchtrac_id: "9")
      allow(feed).to receive(:events).and_return([])

      result = described_class.new(feed: feed, config: config).call

      expect(result.status).to eq("refused")
      expect(result.removed).to eq(0)
      expect(existing.reload).to be_persisted
    end

    it "deletes nothing when the feed raises" do
      existing = build_event(title: "Vespers", starts_at: in_window, churchtrac_id: "9")
      allow(feed).to receive(:events)
        .and_raise(ChurchTrac::CalendarFeed::FeedError, "redirected")

      result = described_class.new(feed: feed, config: config).call

      expect(result.status).to eq("failed")
      expect(result.message).to match(/redirected/)
      expect(existing.reload).to be_persisted
    end

    it "survives a network timeout the same way" do
      allow(feed).to receive(:events).and_raise(Timeout::Error)
      expect(described_class.new(feed: feed, config: config).call.status).to eq("failed")
    end

    it "records the failure so a silent outage is discoverable afterwards" do
      allow(feed).to receive(:events)
        .and_raise(ChurchTrac::CalendarFeed::FeedError, "boom")

      expect { described_class.new(feed: feed, config: config).call }
        .to change(CalendarSync, :count).by(1)
      expect(CalendarSync.last.status).to eq("failed")
    end
  end

  describe "a successful run" do
    it "creates events it has not seen" do
      allow(feed).to receive(:events)
        .and_return([attrs(title: "Vespers", starts_at: in_window)])

      result = described_class.new(feed: feed, config: config).call

      expect(result.status).to eq("ok")
      expect(result.created).to eq(1)
      expect(CalendarEvent.find_by(churchtrac_id: "1").title).to eq("Vespers")
    end

    it "updates an event whose details changed in ChurchTrac" do
      at = in_window
      build_event(title: "Vespers", starts_at: at, churchtrac_id: "1", uid: "u1",
                  synced_at: 1.hour.ago)
      allow(feed).to receive(:events)
        .and_return([attrs(title: "Great Vespers", starts_at: at)])

      result = described_class.new(feed: feed, config: config).call

      expect(result.updated).to eq(1)
      expect(CalendarEvent.find_by(churchtrac_id: "1").title).to eq("Great Vespers")
    end

    # synced_at changes on every run by definition; counting it as a change
    # would report every event as updated every time and make the log useless.
    it "does not count an unchanged event as updated" do
      at = in_window
      build_event(title: "Vespers", starts_at: at, churchtrac_id: "1", uid: "u1",
                  recurring: true, synced_at: 1.hour.ago)
      allow(feed).to receive(:events).and_return([attrs(title: "Vespers", starts_at: at)])

      result = described_class.new(feed: feed, config: config).call

      expect(result.updated).to eq(0)
    end

    it "removes an event that has disappeared from ChurchTrac" do
      gone = build_event(title: "Cancelled meeting", starts_at: in_window,
                         churchtrac_id: "99", synced_at: 1.hour.ago)
      allow(feed).to receive(:events)
        .and_return([attrs(title: "Vespers", starts_at: in_window)])

      result = described_class.new(feed: feed, config: config).call

      expect(result.removed).to eq(1)
      expect { gone.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "what the mirror may not touch" do
    it "leaves locally created events alone — they are not ChurchTrac's to remove" do
      local = build_event(title: "Parish picnic", starts_at: in_window,
                          source: "local", synced_at: 1.hour.ago)
      allow(feed).to receive(:events)
        .and_return([attrs(title: "Vespers", starts_at: in_window)])

      described_class.new(feed: feed, config: config).call

      expect(local.reload).to be_persisted
    end

    it "leaves events outside the window alone, so history is never rewritten" do
      old = build_event(title: "Pascha 2019", starts_at: 6.years.ago,
                        churchtrac_id: "old", synced_at: 1.hour.ago)
      allow(feed).to receive(:events)
        .and_return([attrs(title: "Vespers", starts_at: in_window)])

      described_class.new(feed: feed, config: config).call

      expect(old.reload).to be_persisted
    end
  end

  it "logs every run, successful or not" do
    allow(feed).to receive(:events)
      .and_return([attrs(title: "Vespers", starts_at: in_window)])

    expect { described_class.new(feed: feed, config: config).call }
      .to change(CalendarSync, :count).by(1)

    sync = CalendarSync.last
    expect(sync.status).to eq("ok")
    expect(sync.fetched).to eq(1)
    expect(sync.duration).to be_present
  end
end
