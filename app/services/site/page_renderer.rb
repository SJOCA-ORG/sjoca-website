module Site
  # Everything a template is allowed to see, assembled in one place.
  class PageRenderer
    def initialize(revision) = @revision = revision

    def body(page)
      renderer.render("page", assigns(page))
    end

    def chrome(name, page = nil)
      renderer.render(name, assigns(page))
    end

    private

    def renderer = @renderer ||= Renderer.new(@revision)

    def assigns(page)
      {
        "page"       => page && PageDrop.new(page),
        "nav"        => Page.in_revision(@revision).top_level.in_nav.map { |p| NavDrop.new(p, page&.slug) },
        "site"       => SiteDrop.new
      }
    end
  end
end
