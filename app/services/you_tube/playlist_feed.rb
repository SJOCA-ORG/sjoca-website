require "net/http"
require "json"

module YouTube
  # Reads a public YouTube playlist.
  #
  # There is no feed to use. YouTube retired its RSS endpoints -- both
  # videos.xml?playlist_id= and ?channel_id= now return 404 -- and the Data API
  # would mean an API key for a volunteer parish team to own, rotate and keep
  # within quota. So this reads the playlist page, which is public and needs
  # nothing.
  #
  # That is a scrape, and it is honest about being one: YouTube's markup will
  # change eventually. When it does this raises, the importer refuses to apply
  # anything, and the recordings already mirrored stay put. A wrong answer would
  # be worse than a stale one.
  #
  # Current shape: titles live in `lockupViewModel`, YouTube's newer component.
  # An earlier `playlistVideoRenderer` is gone; if this stops finding anything,
  # that component has been renamed again.
  class PlaylistFeed
    class FeedError < StandardError; end

    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36".freeze

    # "#3 Catechumen Class 10-7-2026" / "#1 Catechumen Class_9-23-2026"
    NUMBER = /#\s*(\d+)/
    DATE   = %r{(\d{1,2})[-/](\d{1,2})[-/](\d{4})}

    def initialize(playlist_id)
      @playlist_id = playlist_id
    end

    def videos
      blob = initial_data(fetch)
      lockups = []
      collect(blob, lockups)
      raise FeedError, "No videos found — YouTube's markup has probably changed" if lockups.empty?

      seen = {}
      lockups.each_with_index.filter_map do |lockup, i|
        id = lockup["contentId"]
        next if id.blank? || seen[id]

        seen[id] = true
        title = first_content(lockup["metadata"]).to_s.strip
        { youtube_id: id, title: title.presence || "Untitled class",
          number: title[NUMBER, 1]&.to_i, held_on: parse_date(title), position: i }
      end
    end

    private

    attr_reader :playlist_id

    def fetch
      uri = URI("https://www.youtube.com/playlist?list=#{playlist_id}")
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                            open_timeout: 20, read_timeout: 20) do |http|
        http.get(uri.request_uri, { "User-Agent" => USER_AGENT,
                                    "Accept-Language" => "en-US,en;q=0.9" })
      end
      raise FeedError, "YouTube returned #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      res.body
    end

    # The page embeds its state as `var ytInitialData = {...};`. Brace-matching
    # rather than a regex, because the object contains braces inside strings.
    def initial_data(html)
      marker = "var ytInitialData = "
      start = html.index(marker) or raise FeedError, "ytInitialData not found in the page"
      start += marker.length
      depth = 0
      in_string = false
      escaped = false
      i = start
      while i < html.length
        c = html[i]
        if in_string
          if escaped          then escaped = false
          elsif c == "\\"     then escaped = true
          elsif c == '"'      then in_string = false
          end
        else
          case c
          when '"' then in_string = true
          when "{" then depth += 1
          when "}"
            depth -= 1
            break if depth.zero?
          end
        end
        i += 1
      end
      JSON.parse(html[start..i])
    rescue JSON::ParserError => e
      raise FeedError, "Could not parse ytInitialData: #{e.message}"
    end

    def collect(node, out)
      case node
      when Hash
        out << node["lockupViewModel"] if node["lockupViewModel"].is_a?(Hash)
        node.each_value { |v| collect(v, out) }
      when Array
        node.each { |v| collect(v, out) }
      end
    end

    def first_content(node)
      case node
      when Hash
        return node["content"] if node["content"].is_a?(String)

        node.each_value { |v| (r = first_content(v)) and return r }
        nil
      when Array
        node.each { |v| (r = first_content(v)) and return r }
        nil
      end
    end

    def parse_date(title)
      m = title.match(DATE) or return nil
      Date.new(m[3].to_i, m[1].to_i, m[2].to_i)
    rescue Date::Error
      nil
    end
  end
end
