module Site
  # What is wrong with how this revision presents itself to a search engine.
  #
  # Run before publishing, every time, because the things that go wrong here go
  # wrong silently and stay wrong for months: a page that never got its own
  # description, two pages sharing one, a photograph with no alt text, a title
  # so long it is cut off in the result.
  #
  # It reports. It does not block, and it does not fix: a description is parish
  # writing, and a check that rewrites prose is a check nobody trusts.
  class SeoCheck
    # Google shows roughly 60 characters of a title and 160 of a description.
    # Past that it truncates, which is not fatal but wastes the only sentence
    # the parish gets in front of somebody searching.
    TITLE_LIMIT = 60
    DESCRIPTION_LIMIT = 160
    DESCRIPTION_FLOOR = 70

    def self.call(revision) = new(revision).call

    def initialize(revision) = @revision = revision

    def call
      pages = Page.in_revision(@revision).ordinary.includes(sections: :blocks).to_a
      {
        checked: pages.size,
        problems: (duplicates(pages) + per_page(pages) + photographs).compact
      }
    end

    private

    def per_page(pages)
      pages.flat_map do |page|
        seo = Seo.new(page, revision: @revision)
        where = page.slug == "home" ? "/" : "/#{page.slug}"
        [
          ("#{where}: the title is #{seo.title.length} characters and will be cut off in a " \
           "search result (#{TITLE_LIMIT} is the room there is)" if seo.title.length > TITLE_LIMIT),

          ("#{where}: no description of its own, so it falls back to the parish's general one. " \
           "A sentence saying what THIS page is would be better." if page.description.blank?),

          ("#{where}: the description is #{seo.description.length} characters and will be cut " \
           "off (#{DESCRIPTION_LIMIT} is the room)" if seo.description.length > DESCRIPTION_LIMIT),

          ("#{where}: the description is only #{seo.description.length} characters — too short " \
           "to say much" if seo.description.length < DESCRIPTION_FLOOR),

          ("#{where}: no heading on the page at all" if headings(page).zero?)
        ]
      end
    end

    # Two pages with the same description tell a search engine they are the
    # same page, and it then picks one of them to show.
    def duplicates(pages)
      described = pages.reject { |p| p.description.blank? }
      described.group_by(&:description).filter_map do |text, sharing|
        next if sharing.one?

        "#{sharing.map { |p| "/#{p.slug}" }.join(' and ')} share one description " \
          "(#{text.truncate(50)}) — a search engine reads that as one page"
      end
    end

    # Alt text is what a screen reader announces, and the only thing a search
    # engine can read in a photograph.
    def photographs
      names = Block.where(revision: @revision, kind: "image").pluck(:asset_name, :asset_version).uniq
      missing = names.filter_map { |name, version|
        photo = Photo.find_version(name, version)
        name if photo && photo.alt_text.blank?
      }
      return [] if missing.empty?

      ["#{missing.size} #{'photograph'.pluralize(missing.size)} on the site have no description: " \
       "#{missing.first(4).join(', ')}"]
    end

    def headings(page)
      page.sections.sum { |s| s.blocks.count { |b| b.kind.in?(%w[heading subheading]) } }
    end
  end
end
