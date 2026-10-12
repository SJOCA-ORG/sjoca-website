require "net/http"

module Oca
  # Reads the daily scripture readings published at oca.org.
  #
  #   https://www.oca.org/readings/daily/2026/10/12
  #
  # Each day lists its readings as links; each link leads to the full text,
  # labelled with its kind ("Gospel", "Epistle"). We take both.
  #
  # There is no API, so this parses the page. It is a gentler scrape than most:
  # the markup is plain server-rendered HTML with no JavaScript, and the content
  # for a given date never changes once published — so each day is fetched once,
  # ever, and then left alone.
  #
  # Which readings count: some days carry more than two. The last two are the
  # ones appointed in the lectionary for that day; earlier entries belong to a
  # commemoration. That rule comes from the parish, not from the markup.
  class LectionaryFeed
    class FeedError < StandardError; end

    BASE = "https://www.oca.org".freeze
    USER_AGENT = "SJOCA parish website (https://www.sjoca.org) — daily readings".freeze
    PAUSE = 0.4  # be a polite guest on someone else's server

    def day(date)
      doc = get("/readings/daily/#{date.year}/#{format('%02d', date.month)}/#{format('%02d', date.day)}")

      header = doc.at_css("#content-header h2")&.text.to_s
      title  = header.sub(/\A.*?-->/m, "").strip.presence

      links = doc.css("#main-col-contents section ul li a").select { |a|
        a["href"].to_s.match?(%r{/readings/daily/\d+/\d+/\d+/\d+})
      }
      raise FeedError, "No readings found for #{date} — oca.org markup may have changed" if links.empty?

      readings = links.each_with_index.map do |a, i|
        sleep PAUSE
        detail(a["href"]).merge(position: i + 1,
                                citation: a.text.strip,
                                source_url: "#{BASE}#{a['href']}")
      end

      commemorations = doc.css("#main-col-contents section p").map(&:text)
                          .map { |t| t.squish }.find { |t| t.length > 40 }

      { on: date, title: title, commemorations: commemorations, readings: readings }
    end

    private

    # The reading page carries the full text as a definition list: verse number
    # in <dt>, the verse itself in <dd>.
    def detail(path)
      doc  = get(path)
      kind = doc.at_css("#main-col-contents h3, #main-col-contents h2 ~ p")&.text.to_s[/\(([^)]+)\)/, 1]
      kind ||= doc.to_html[/\(\s*(Gospel|Epistle|Matins Gospel|Old Testament)[^)]*\)/i, 1]

      verses = doc.css("dl.reading").flat_map { |dl|
        dl.css("dt").zip(dl.css("dd")).map { |dt, dd|
          next if dd.nil?
          "#{dt.text.strip} #{dd.text.squish}"
        }.compact
      }
      { kind: kind&.strip, body: verses.join("\n").presence }
    end

    def get(path)
      uri = URI("#{BASE}#{path}")
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                            open_timeout: 20, read_timeout: 20) do |http|
        http.get(uri.request_uri, { "User-Agent" => USER_AGENT,
                                    "Accept" => "text/html" })
      end
      raise FeedError, "oca.org returned #{res.code} for #{path}" unless res.is_a?(Net::HTTPSuccess)

      Nokogiri::HTML(res.body)
    end
  end
end
