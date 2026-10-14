# Builders for page content. Deliberately not FactoryBot: the shapes here are
# small, and a spec that spells out the structure it is testing reads better
# than one that hides it behind a factory.
module ContentBuilders
  # All content belongs to a revision. Specs get one published revision each,
  # so Revision.live -- which is how the controllers resolve it -- finds it.
  # Specs render through the real Liquid templates, not a stub -- a spec that
  # passes against made-up markup proves nothing about the site.
  def test_revision
    @test_revision ||= Revision.create!(state: "published", title: "spec").tap do |r|
      DefaultTemplates.install!(r)
    end
  end

  def build_page(slug: "home", title: "Home", nav_title: "Home",
                 revision: nil, **attrs)
    Page.create!(slug: slug, title: title, nav_title: nav_title,
                 revision: revision || test_revision, **attrs)
  end

  def build_section(page:, style: "plain", **attrs)
    page.sections.create!(style: style, revision: page.revision, **attrs)
  end

  def build_block(section:, kind: "text", content: "Hello", **attrs)
    section.blocks.create!(kind: kind, content: content,
                           revision: section.revision, **attrs)
  end

  # byte_size is NOT NULL at the database but is neither defaulted nor validated
  # by the model -- every caller computes it. See docs/TODO.md.
  def build_asset(human_name: "home-hero", bytes: "PNGDATA", status: "published", **attrs)
    Photo.create!(
      human_name: human_name, content_type: "image/png", data: bytes,
      byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
      status: status, **attrs
    )
  end

  # Likewise synced_at on calendar_events: the importers set it, the model does
  # not default it.
  def build_event(title: "Vespers", starts_at: 2.days.from_now, source: "churchtrac",
                  recurring: true, **attrs)
    CalendarEvent.create!(title: title, starts_at: starts_at, source: source,
                          recurring: recurring,
                          synced_at: attrs.delete(:synced_at) || Time.current, **attrs)
  end
end

RSpec.configure { |c| c.include ContentBuilders }
