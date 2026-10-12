module Oca
  # Mirrors the daily readings for a window of dates.
  #
  # A day already stored is skipped entirely: the lectionary for a past or
  # present date does not change, so each day is fetched exactly once in its
  # life. That keeps us a light visitor on oca.org and makes the task cheap to
  # run every morning.
  class LectionaryImporter
    Result = Struct.new(:status, :fetched, :created, :skipped, :failed, :message,
                        keyword_init: true)

    def initialize(feed: LectionaryFeed.new, days_ahead: 21)
      @feed = feed
      @days_ahead = days_ahead
    end

    def call(from: Date.current)
      created = skipped = failed = 0
      last_error = nil

      (from..(from + @days_ahead)).each do |date|
        if LectionaryDay.exists?(on: date)
          skipped += 1
          next
        end

        begin
          store(feed.day(date))
          created += 1
        rescue LectionaryFeed::FeedError, SocketError, Timeout::Error => e
          failed += 1
          last_error = "#{date}: #{e.message}"
          # Keep going: one bad day should not stop the rest of the fortnight.
        end
      end

      status = if created.positive? || failed.zero? then "ok" else "failed" end
      Result.new(status: status, fetched: created + skipped, created: created,
                 skipped: skipped, failed: failed, message: last_error)
    end

    private

    attr_reader :feed

    def store(data)
      LectionaryDay.transaction do
        day = LectionaryDay.create!(
          on: data[:on], title: data[:title],
          commemorations: data[:commemorations], synced_at: Time.current
        )
        data[:readings].each do |r|
          day.readings.create!(position: r[:position], citation: r[:citation],
                               kind: r[:kind], body: r[:body], source_url: r[:source_url])
        end
      end
    end
  end
end
