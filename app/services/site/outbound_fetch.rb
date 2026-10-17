require "net/http"
require "resolv"
require "ipaddr"

module Site
  # The one place this application reaches out to the internet on behalf of
  # something the AI wrote.
  #
  # That is the whole reason this file is careful. Everywhere else, a URL is
  # chosen by a developer and reviewed in a pull request. Here the URL arrives
  # from a conversation with a parish volunteer, and the request is made by our
  # server, from inside Render's private network -- where
  # http://169.254.169.254/ is the cloud metadata endpoint and localhost:5432 is
  # the parish database. An unguarded fetch primitive is a server-side request
  # forgery hole with a friendly interface.
  #
  # So: HTTPS only, every resolved address checked against the private ranges,
  # and checked AGAIN after each redirect -- a public URL is allowed to redirect
  # to 127.0.0.1, and that is the bug people actually ship. Nothing of ours is
  # ever sent: no cookies, no credentials, no headers but the ones below.
  class OutboundFetch
    class Refused < StandardError; end

    MAX_BYTES     = 8.megabytes
    MAX_REDIRECTS = 3
    OPEN_TIMEOUT  = 10
    READ_TIMEOUT  = 20

    # ChurchTrac's load balancer returns 403 to anything that does not look like
    # a browser, and redirects HeadlessChrome to its marketing homepage. See
    # docs/churchtrac-integration.md -- this cost real time once.
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36".freeze

    # Served to a browser, so it must be something a browser would accept as
    # data. No octet-stream, no PDFs, nothing executable.
    ALLOWED_TYPES = %w[application/json application/ld+json text/json text/plain
                       text/html text/xml application/xml application/rss+xml
                       application/atom+xml text/csv text/calendar].freeze

    Result = Struct.new(:url, :body, :content_type, :status, keyword_init: true)

    def self.call(url) = new(url).call

    def initialize(url) = @url = url.to_s.strip

    def call
      uri = parse(@url)
      redirects = 0

      loop do
        guard!(uri)
        response = request(uri)

        case response
        when Net::HTTPRedirection
          redirects += 1
          raise Refused, "that address redirects more than #{MAX_REDIRECTS} times" if redirects > MAX_REDIRECTS

          location = response["location"].to_s
          raise Refused, "a redirect gave no address to follow" if location.blank?

          # Re-enter the loop so guard! runs again on the new address. A
          # redirect to a private address is the SSRF bypass that matters.
          uri = parse(URI.join(uri, location).to_s)
          next
        when Net::HTTPSuccess
          return success(uri, response)
        else
          raise Refused, "#{uri.host} answered #{response.code} #{response.message}"
        end
      end
    end

    private

    def parse(url)
      uri = URI.parse(url)
      raise Refused, "#{url.inspect} is not a web address" unless uri.is_a?(URI::HTTP)
      raise Refused, "only https addresses are allowed, not #{uri.scheme}" unless uri.scheme == "https"
      raise Refused, "that address has no host" if uri.host.blank?
      raise Refused, "an address with a username or password in it is not allowed" if uri.userinfo.present?

      uri
    rescue URI::InvalidURIError
      raise Refused, "#{url.inspect} is not a valid address"
    end

    # Every address the host resolves to must be public. Checking one is not
    # enough: a name can return several, and a name under someone else's control
    # can return a public address now and a private one on the next lookup.
    def guard!(uri)
      addresses = resolve(uri.host)
      raise Refused, "#{uri.host} does not resolve to anything" if addresses.empty?

      addresses.each do |ip|
        next if public_address?(ip)

        raise Refused, "#{uri.host} resolves to #{ip}, which is inside this network rather than " \
                       "out on the internet. Addresses like that are refused: it is how a " \
                       "fetch gets turned into a way of reading our own servers."
      end
    end

    def resolve(host)
      return [IPAddr.new(host)] if ip_literal?(host)

      Resolv.getaddresses(host).filter_map { |a| IPAddr.new(a) rescue nil }
    rescue Resolv::ResolvError
      []
    end

    def ip_literal?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end

    def public_address?(ip)
      return false if ip.loopback? || ip.private? || ip.link_local?
      return false if ip.to_range.first == ip.to_range.last && ip.to_i.zero?

      # IPAddr#private? covers RFC1918 and fc00::/7 but not these.
      refused = ip.ipv4? ? %w[0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15
                              198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
                              255.255.255.255/32]
                         : %w[::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001:db8::/32
                              fe80::/10 fc00::/7 ff00::/8]
      refused.none? { |range| IPAddr.new(range).include?(ip) }
    end

    def request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        # Nothing of ours travels with this: no cookies, no authorization, no
        # referer that would leak a preview token.
        http.request(Net::HTTP::Get.new(uri, {
          "User-Agent" => USER_AGENT,
          "Accept" => "application/json, text/html, text/plain, */*",
          "Accept-Language" => "en-US,en;q=0.9"
        }))
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Refused, "#{uri.host} did not answer within #{READ_TIMEOUT} seconds"
    rescue OpenSSL::SSL::SSLError => e
      raise Refused, "the secure connection to #{uri.host} failed: #{e.message}"
    rescue SocketError => e
      raise Refused, "could not reach #{uri.host}: #{e.message}"
    end

    def success(uri, response)
      type = response["content-type"].to_s.split(";").first.to_s.strip.downcase
      unless ALLOWED_TYPES.include?(type)
        raise Refused, "#{uri.host} returned #{type.presence || 'an unknown type'}, which is not " \
                       "text or data. Only JSON, HTML, XML, CSV and plain text can be used here."
      end

      body = response.body.to_s
      if body.bytesize > MAX_BYTES
        raise Refused, "#{uri.host} returned #{ActiveSupport::NumberHelper.number_to_human_size(body.bytesize)}, " \
                       "over the #{ActiveSupport::NumberHelper.number_to_human_size(MAX_BYTES)} limit"
      end

      Result.new(url: uri.to_s, body: body.dup.force_encoding("UTF-8").scrub,
                 content_type: type, status: response.code.to_i)
    end
  end
end
