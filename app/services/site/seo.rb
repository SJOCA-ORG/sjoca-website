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
    # No constants naming the parish. A title suffix and a fallback description
    # need SOMETHING to call the site, and that comes from the site's own
    # settings, in its own revision -- so this code serves a second parish
    # without being told which parish it is.
    def site = @site ||= SiteDrop.new(@revision)

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
      return own.presence || site.name if home?

      "#{own} — #{site.name}"
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
        "og:site_name" => site.name,
        "og:title" => title,
        "og:description" => description,
        "og:url" => canonical,
        "og:locale" => "en_US",
        "og:image" => hero_url
      }.compact
    end

    # structured_data used to live here: the name, the address, "@type":
    # "Church", and the service times, which were filtered out of the ChurchTrac
    # feed by a list of title patterns in Ruby.
    #
    # It was removed on 27 October 2026 because Ruby should not know that this
    # parish is a church, what its services are called, or when they meet. That
    # is the parish's to say, and it now says it in the "head" template in its
    # own revision, where it can be read and corrected by asking.
    #
    # The removal was not merely tidiness. The Ruby filter was WRONG: the Hours
    # at 9:30 on a Sunday are on the home page and were missing from what Google
    # was told, because they did not match a pattern nobody could see.

    private

    def home? = @page.slug == "home"
    def base = site.url

    # What the site says about itself when a page offers nothing of its own.
    # A SETTING, not a sentence in Ruby: Ruby knows a site has a description,
    # not that this one is a parish of the OCA.
    def default_description
      site.setting("description").presence ||
        "#{site.name} in #{site.setting('city')}, #{site.setting('region')}."
    end

    # The opening of the page itself, which describes this page rather than the
    # parish in general.
    def derived_description
      return nil unless @page.respond_to?(:sections)

      text = @page.sections.flat_map { |s| s.blocks.select { |b| b.kind == "text" } }
                  .map { |b| b.content.to_s.gsub(/<[^>]*>/, " ").squish }
                  .find { |t| t.length > 60 }
      return nil if text.blank?

      "#{text.truncate(150, separator: ' ')} — #{site.name}, #{site.setting('city')} #{site.setting('region')}."
    end

    def hero_url
      name = @page.try(:hero_asset_name)
      version = @page.try(:hero_asset_version)
      return nil if name.blank? || version.blank?

      "#{base}/media/#{name}/#{version}"
    end

    # service_hours went with it, and took the last reference to CalendarEvent.
  end
end
