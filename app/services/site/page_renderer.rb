module Site
  # Everything a template is allowed to see, assembled in one place.
  class PageRenderer
    def initialize(revision) = @revision = revision

    # The page's LAYOUT picks its template. An ordinary page flows; a bulletin
    # is 5.5 x 8.5 and its sections are sheets of paper rather than bands of
    # colour, so it cannot render through the same template.
    #
    # Falls back to "page" if a revision has no bulletin template yet, rather
    # than failing: a missing template should not take a site down.
    def body(page)
      renderer.render(template_for(page), assigns(page))
    end

    def template_for(page)
      return "page" unless page.respond_to?(:layout) && page.layout.to_s != "page"
      return page.layout if @revision.templates.exists?(name: page.layout)

      "page"
    end

    def chrome(name, page = nil)
      renderer.render(name, assigns(page))
    end

    # Whatever the parish wants in the <head> of every page -- structured data,
    # a verification tag, anything.
    #
    # This exists so that Ruby does not have to know the parish is a church,
    # what its services are called, or when they happen. It knows how to render
    # a template; the template says what the parish IS, and the parish can read
    # and change it. Missing is normal: a site need not have one.
    def head(page = nil)
      return "" unless @revision&.templates&.exists?(name: "head")

      renderer.render("head", assigns(page))
    rescue StandardError => e
      # The head of every page on the site. A mistake in it must not take the
      # site down -- it loses the structured data and says so in the log.
      Rails.logger.warn("head template failed: #{e.message}")
      ""
    end

    private

    def renderer = @renderer ||= Renderer.new(@revision)

    def assigns(page)
      {
        "page"       => page && PageDrop.new(page),
        "nav"        => Page.in_revision(@revision).top_level.in_nav.map { |p| NavDrop.new(p, page&.slug) },
        "site"       => SiteDrop.new(@revision)
      }
    end
  end
end
