module ChurchTrac
  # Mirrors the ChurchTrac calendar into calendar_events.
  #
  # Window: one month back through twelve months forward, by default. We keep a
  # month behind so the current month stays whole, and never backfill further —
  # the past does not change, and re-fetching it would only risk rewriting it.
  #
  # Within the window the mirror is authoritative: an event cancelled in
  # ChurchTrac disappears here too. Outside it, nothing is touched.
  #
  # The refusal below matters more than it looks. A sync that fails open — one
  # that treats a bad response as "no events" — would silently empty the
  # parish calendar, and an empty calendar looks entirely plausible. So a failed
  # fetch deletes nothing, and a window that comes back suspiciously empty is
  # refused rather than applied.
  # Named Importer rather than Sync so it cannot be confused with the
  # CalendarSync model that logs each run — inside module ChurchTrac, a bare
  # `CalendarSync` would resolve to this class and the logging would silently
  # fail, which is exactly what happened first time round.
  class CalendarImporter
    MIN_EVENTS_TO_PRUNE = 1

    Result = Struct.new(:status, :fetched, :created, :updated, :removed, :message,
                        keyword_init: true)

    def initialize(feed: CalendarFeed.new, config: Rails.application.config.church_trac)
      @feed   = feed
      @config = config
    end

    def call
      started = Time.current
      from = config.months_back.months.ago.beginning_of_month
      to   = config.months_forward.months.from_now.end_of_month

      events = feed.events(from: from, to: to)
      result = apply(events, from, to)

      record(result, from, to, Time.current - started)
      result
    rescue CalendarFeed::FeedError, SocketError, Timeout::Error => e
      result = Result.new(status: "failed", fetched: 0, created: 0, updated: 0,
                          removed: 0, message: e.message)
      record(result, from, to, Time.current - started)
      result
    end

    private

    attr_reader :feed, :config

    def apply(events, from, to)
      if events.size < MIN_EVENTS_TO_PRUNE
        return Result.new(status: "refused", fetched: events.size, created: 0, updated: 0,
                          removed: 0,
                          message: "Feed returned #{events.size} events; refusing to " \
                                   "prune in case this is an upstream failure")
      end

      created = updated = 0
      now = Time.current

      CalendarEvent.transaction do
        events.each do |attrs|
          record = CalendarEvent.from_churchtrac.find_or_initialize_by(
            churchtrac_id: attrs[:churchtrac_id], starts_at: attrs[:starts_at]
          )
          was_new = record.new_record?
          record.assign_attributes(attrs.merge(synced_at: now))
          # synced_at always changes, so judge "updated" on the real fields.
          changed = (record.changed - %w[synced_at updated_at]).any?
          record.save!
          if was_new then created += 1
          elsif changed then updated += 1
          end
        end

        # Anything in the window we did not just see has gone from ChurchTrac.
        # Scoped to ChurchTrac's own events: locally created ones are not theirs
        # to remove.
        removed = CalendarEvent.from_churchtrac.between(from, to)
                               .where("synced_at < ?", now).delete_all

        return Result.new(status: "ok", fetched: events.size, created: created,
                          updated: updated, removed: removed, message: nil)
      end
    end

    def record(result, from, to, duration)
      ::CalendarSync.create!(
        status: result.status, window_start: from, window_end: to,
        fetched: result.fetched, created: result.created, updated: result.updated,
        removed: result.removed, message: result.message, duration: duration
      )
    rescue StandardError => e
      Rails.logger.warn("Could not record calendar sync: #{e.message}")
    end
  end
end
