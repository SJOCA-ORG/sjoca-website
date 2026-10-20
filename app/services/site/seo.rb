module Site
  # What a page tells a search engine about itself.
  #
  # The parish's own goal, in Mitch's words: that somebody searching "orthodox
  # church near me" in Rochester finds us. Most of what follows is ordinary
  # hygiene -- a title that says what the page is, a description per page, one
  # canonical address for each thing. The part that actually earns its keep for
  # a local search is the structured data: an address, and the SERVICE TIMES,
  # taken from the calendar the parish already keeps rather than typed again
  # here and left to rot.
  #
  # Worth saying plainly, because it is the thing nobody wants to hear: none of
  # this outranks a Google Business Profile. For "near me" that listing is the
  # single largest factor and it is not a website feature. See docs/seo.md.
  class Seo
    NAME = "Saint John the Baptist Orthodox Church".freeze
    STREET = "855 S. Goodman St.".freeze
    CITY = "Rochester".freeze
    REGION = "NY".freeze
    POSTCODE = "14620".freeze

    # Omitted rather than guessed. Coordinates nobody checked are worse than no
    # coordinates: they put the pin in the wrong street and no one notices.
    # Set SJOCA_LATITUDE and SJOCA_LONGITUDE from the parish's own listing.
    def self.coordinates
      lat = ENV["SJOCA_LATITUDE"].presence
      lon = ENV["SJOCA_LONGITUDE"].presence
      return nil if lat.nil? || lon.nil?

      { "@type" => "GeoCoordinates", "latitude" => lat.to_f, "longitude" => lon.to_f }
    end

    def initialize(page, revision: nil)
      @page = page
      @revision = revision
    end

    # The home page does not append the parish name, because its title already
    # IS the parish name -- doing both produced "Saint John the Baptist
    # Orthodox Church — Saint John the Baptist Orthodox Church". It keeps
    # whatever the page itself says, rather than being silently replaced: the
    # title is parish content and not mine to rewrite.
    def title
      own = @page.title.to_s.strip
      return own.presence || NAME if home?

      "#{own} — #{NAME}"
    end

    def description
      @page.description.presence || derived_description || default_description
    end

    # One address per thing. /home and / served the same page, which tells a
    # search engine they are two pages with identical content -- the oldest
    # self-inflicted ranking problem there is.
    def canonical = "#{base}#{path}"

    def path = home? ? "/" : "/#{@page.slug}"

    def open_graph
      {
        "og:type" => "website",
        "og:site_name" => NAME,
        "og:title" => title,
        "og:description" => description,
        "og:url" => canonical,
        "og:locale" => "en_US",
        "og:image" => hero_url
      }.compact
    end

    # A church, with its address and when it actually meets. The service times
    # come from the mirrored calendar, so they cannot drift from what the
    # parish publishes.
    def structured_data
      data = {
        "@context" => "https://schema.org",
        "@type" => "Church",
        "name" => NAME,
        "alternateName" => "St John the Baptist Orthodox Church",
        "description" => default_description,
        "url" => base,
        "address" => {
          "@type" => "PostalAddress",
          "streetAddress" => STREET,
          "addressLocality" => CITY,
          "addressRegion" => REGION,
          "postalCode" => POSTCODE,
          "addressCountry" => "US"
        },
        "email" => SiteDrop.new.email,
        "image" => hero_url,
        "parentOrganization" => {
          "@type" => "Organization",
          "name" => "Orthodox Church in America",
          "url" => "https://www.oca.org"
        }
      }
      data["geo"] = self.class.coordinates if self.class.coordinates
      data["openingHoursSpecification"] = service_hours if service_hours.any?
      data.compact
    end

    private

    def home? = @page.slug == "home"
    def base = SiteDrop.new.url

    def default_description
      "#{NAME} in #{CITY}, #{REGION} — a parish of the Orthodox Church in America (OCA), " \
      "Diocese of New York and New Jersey. Services entirely in English. All are welcome."
    end

    # The opening of the page itself, which describes this page rather than the
    # parish in general.
    def derived_description
      return nil unless @page.respond_to?(:sections)

      text = @page.sections.flat_map { |s| s.blocks.select { |b| b.kind == "text" } }
                  .map { |b| b.content.to_s.gsub(/<[^>]*>/, " ").squish }
                  .find { |t| t.length > 60 }
      return nil if text.blank?

      "#{text.truncate(150, separator: ' ')} — #{NAME}, #{CITY} #{REGION}."
    end

    def hero_url
      name = @page.try(:hero_asset_name)
      version = @page.try(:hero_asset_version)
      return nil if name.blank? || version.blank?

      "#{base}/media/#{name}/#{version}"
    end

    # The regular round, as the calendar has it: the services that recur, with
    # the day and time they recur at. One entry per weekday and time.
    def service_hours
      @service_hours ||= begin
        upcoming = CalendarEvent.within(21).select(&:scheduled_service?)
        upcoming.group_by { |e| [e.starts_at.strftime("%A"), e.starts_at.strftime("%H:%M")] }
                .keys.sort
                .map do |day, at|
          { "@type" => "OpeningHoursSpecification",
            "dayOfWeek" => "https://schema.org/#{day}",
            "opens" => at,
            "closes" => (Time.zone.parse(at) + 90.minutes).strftime("%H:%M") }
        end
      end
    rescue StandardError
      []
    end
  end
end
