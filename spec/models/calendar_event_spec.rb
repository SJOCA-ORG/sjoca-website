require "rails_helper"

RSpec.describe CalendarEvent do
  def event(title:, **attrs) = build_event(title: title, **attrs)

  # The distinction the Service Times block depends on. Getting it wrong either
  # buries a feast day among the ordinary weekly services, or fills "upcoming
  # events" with the same Vespers every week until nobody reads it.
  describe "#scheduled_service?" do
    it "recognises the published services" do
      ["Vespers", "Great Vespers", "Divine Liturgy", "Akathist", "Hours",
       "Reading of the Hours", "Compline"].each do |title|
        expect(event(title: title)).to be_scheduled_service, "expected #{title.inspect}"
      end
    end

    it "is case and whitespace insensitive" do
      expect(event(title: "  divine LITURGY  ")).to be_scheduled_service
    end

    # An extra Vespers put on for a feast is not the ordinary Saturday one, and
    # a visitor would want to hear about it.
    it "is false for a one-off occurrence of a service title" do
      expect(event(title: "Vespers", recurring: false)).not_to be_scheduled_service
    end

    it "is false for things that merely contain a service name" do
      expect(event(title: "Vespers Choir Rehearsal")).not_to be_scheduled_service
      expect(event(title: "Parish Council Meeting")).not_to be_scheduled_service
    end
  end

  describe "#cancellation?" do
    it "spots the ways a parish announces one" do
      ["No Vespers", "Vespers Cancelled", "Vespers canceled", "CANCELLED - Liturgy"]
        .each { |t| expect(event(title: t)).to be_cancellation, "expected #{t.inspect}" }
    end

    it "does not fire on an unrelated word starting with 'no'" do
      expect(event(title: "Nocturne Recital")).not_to be_cancellation
    end
  end

  # A cancelled service must surface even though it is a scheduled service --
  # that is the whole reason cancellations are announced as events.
  describe "#noteworthy?" do
    it "includes anything that is not an ordinary scheduled service" do
      expect(event(title: "Parish Council Meeting")).to be_noteworthy
      expect(event(title: "Adult Education")).to be_noteworthy
    end

    it "excludes the ordinary weekly services" do
      expect(event(title: "Divine Liturgy")).not_to be_noteworthy
    end

    it "includes a cancelled service even though the title is a service" do
      expect(event(title: "No Vespers")).to be_noteworthy
    end
  end

  describe "#time_text" do
    around { |ex| Time.use_zone("America/New_York") { ex.run } }

    it "drops the :00 on the hour" do
      expect(event(title: "Vespers",
                   starts_at: Time.zone.parse("2026-10-17 18:00")).time_text).to eq("6pm")
    end

    it "keeps real minutes" do
      expect(event(title: "Liturgy",
                   starts_at: Time.zone.parse("2026-10-18 09:30")).time_text).to eq("9:30am")
    end

    it "is nil for an all-day event, so nothing renders '12am'" do
      e = event(title: "Nativity", starts_at: Time.zone.parse("2026-12-25 00:00"),
                all_day: true)
      expect(e.time_text).to be_nil
    end

    it "is nil for a midnight start, which ChurchTrac uses to mean 'no time'" do
      e = event(title: "Feast", starts_at: Time.zone.parse("2026-12-25 00:00"))
      expect(e.time_text).to be_nil
    end
  end

  describe "#elsewhere" do
    it "is nil at the parish's own building" do
      expect(event(title: "Vespers", location: "4100 Goodman St N").elsewhere).to be_nil
    end

    it "names anywhere else" do
      expect(event(title: "Outreach", location: "Open Door Mission").elsewhere)
        .to eq("Open Door Mission")
    end

    it "is nil when no location was given at all" do
      expect(event(title: "Vespers").elsewhere).to be_nil
    end
  end

  describe "scopes" do
    it "upcoming includes today and excludes yesterday" do
      past   = event(title: "Past",  starts_at: 2.days.ago)
      today  = event(title: "Today", starts_at: Time.current.change(hour: 23))
      future = event(title: "Soon",  starts_at: 3.days.from_now)

      expect(described_class.upcoming).to include(today, future)
      expect(described_class.upcoming).not_to include(past)
    end

    it "orders upcoming by start time" do
      later   = event(title: "Later",   starts_at: 5.days.from_now)
      sooner  = event(title: "Sooner",  starts_at: 1.day.from_now)
      expect(described_class.upcoming.to_a).to eq([sooner, later])
    end
  end

  describe "uniqueness" do
    # The importer keys on (churchtrac_id, starts_at): a recurring event shares
    # one id across every occurrence, so the id alone is not unique.
    it "allows one ChurchTrac id at several start times" do
      event(title: "Vespers", starts_at: 1.day.from_now,  churchtrac_id: "42")
      expect { event(title: "Vespers", starts_at: 8.days.from_now, churchtrac_id: "42") }
        .not_to raise_error
    end

    it "rejects the same id at the same start time" do
      at = 1.day.from_now.change(usec: 0)
      event(title: "Vespers", starts_at: at, churchtrac_id: "42")
      expect { event(title: "Vespers", starts_at: at, churchtrac_id: "42") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
