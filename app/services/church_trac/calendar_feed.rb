require "net/http"
require "json"

module ChurchTrac
  # Fetches the parish calendar from ChurchTrac's public JSON feed.
  #
  #   GET /calendar_events?source=public&church_ui=…&start=…&end=…
  #
  # This is the same endpoint their own embedded widget uses, so it is as stable
  # as the widget itself. No scraping involved.
  #
  # Two things will bite anyone who touches this:
  #
  #   * A request without a browser-like User-Agent gets 403 from their load
  #     balancer, and one that looks like HeadlessChrome gets 302'd to their
  #     marketing homepage — returning 115KB of HTML that parses as zero events.
  #     We spent real time fooled by exactly that. Hence the UA below, and the
  #     hard failure on a non-JSON response rather than treating it as "empty".
  #
  #   * The start/end parameters are a hint, not a filter: asking for October
  #     returns events from months either side. Callers must filter.
  class CalendarFeed
    class FeedError < StandardError; end

    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36".freeze
    TIMEOUT = 30

    def initialize(config = Rails.application.config.church_trac)
      @config = config
    end

    # Events whose start falls within [from, to], newest fetch wins.
    def events(from:, to:)
      raw = get(from, to)
      raw.filter_map { |e| normalise(e) }
         .select { |e| e[:starts_at].between?(from.beginning_of_day, to.end_of_day) }
         .sort_by { |e| e[:starts_at] }
    end

    private

    attr_reader :config

    def get(from, to)
      uri = URI("#{config.base_url}/calendar_events")
      uri.query = URI.encode_www_form(
        source: "public", church_ui: config.church_ui,
        start: from.to_date.iso8601, end: to.to_date.iso8601
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, {
          "User-Agent"       => USER_AGENT,
          "Accept"           => "application/json, text/javascript, */*; q=0.01",
          "X-Requested-With" => "XMLHttpRequest",
          "Referer"          => "#{config.base_url}/public_calendar?ui=#{config.church_ui}"
        })
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise FeedError, "ChurchTrac returned #{response.code} for #{uri}"
      end

      parsed = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        # Almost certainly the redirect-to-homepage behaviour. Say so, because
        # "0 events" would look like a parish with nothing scheduled.
        raise FeedError, "ChurchTrac returned #{response.body.bytesize} bytes of " \
                         "#{response['content-type']}, not JSON — likely redirected"
      end

      raise FeedError, "Expected a JSON array, got #{parsed.class}" unless parsed.is_a?(Array)

      parsed
    end

    # Times come back as "2026-10-03 18:00:00" with no zone, and they are local
    # parish time — hence Time.zone, with the app pinned to America/New_York.
    def normalise(event)
      starts_at = parse(event["start"]) or return nil
      {
        churchtrac_id: event["id"].to_s,
        uid:           event["UID"].presence,
        title:         event["title"].to_s.strip.presence || "(untitled)",
        starts_at:     starts_at,
        ends_at:       parse(event["end"]),
        all_day:       ActiveModel::Type::Boolean.new.cast(event["allDay"]) || false,
        recurring:     event["recurring"].to_s.present? && event["recurring"].to_s != "0",
        location:      event["location"].presence,
        notes:         event["notes"].presence,
        calendar_name: event["calendar"].presence
      }
    end

    def parse(value) = value.present? ? Time.zone.parse(value.to_s) : nil
  end
end
