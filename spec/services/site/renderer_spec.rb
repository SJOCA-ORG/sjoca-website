require "rails_helper"

# The site is rendered from templates stored in the database. These specs cover
# what that port has to keep true -- and two traps that cost real time.
RSpec.describe Site::Renderer do
  let(:revision) { test_revision }
  let(:page)     { build_page(slug: "giving", title: "Giving", nav_title: "Giving") }
  let(:renderer) { Site::PageRenderer.new(revision) }

  describe "every block kind renders" do
    # If a kind has no template it vanishes silently, which on a parish site
    # means content disappearing with nothing to notice.
    Block::KINDS.each do |kind|
      it "renders a #{kind} block without error" do
        section = build_section(page: page)
        build_block(section: section, kind: kind, content: "Sample #{kind}")

        expect { renderer.body(page.reload) }.not_to raise_error
      end
    end

    it "has a template for every declared kind" do
      names = revision.templates.pluck(:name)
      Block::KINDS.each do |kind|
        expect(names).to include("block/#{kind}"), "no template for block kind #{kind.inspect}"
      end
    end
  end

  describe "content safety" do
    # Liquid does not escape by default, so anything landing in an attribute
    # must be escaped by the drop. A quote in an alt text silently truncated
    # the attribute and lost the rest of the description.
    it "escapes a quote in a photograph's alt text" do
      photo = build_asset(human_name: "quoted")
      photo.update!(alt_text: %(An icon holding a scroll reading "Repent"))
      section = build_section(page: page)
      build_block(section: section, kind: "image", asset_name: "quoted")

      html = renderer.body(page.reload)
      expect(html).to include("&quot;Repent&quot;")
      expect(html).not_to include(%(alt="An icon holding a scroll reading "Repent""))
    end

    it "strips markup the parish is not allowed to write" do
      section = build_section(page: page)
      build_block(section: section, kind: "text", content: "<script>alert(1)</script>Hello")

      expect(renderer.body(page.reload)).not_to include("<script>")
    end

    it "keeps the inline markup that is allowed" do
      section = build_section(page: page)
      build_block(section: section, kind: "text", content: %(Visit <a href="/giving">Giving</a>))

      expect(renderer.body(page.reload)).to include(%(<a href="/giving">Giving</a>))
    end
  end

  # In Liquid only nil and false are falsy -- "" is truthy. Every {% if %}
  # guarding an optional field rendered an empty tag until the drops returned
  # nil for blank.
  it "omits an optional hero field rather than rendering an empty tag" do
    page.update!(hero_heading: "Giving", hero_subheading: "")

    html = renderer.body(page.reload)
    expect(html).to include("hero__title")
    expect(html).not_to include("hero__subtitle")
  end

  describe "nesting" do
    # {% render %} isolates scope, unlike {% include %}. A block template that
    # reaches `site` silently rendered NOTHING until site was passed down
    # through every level, and three pages collapsed to an empty band while
    # still returning 200. This is that regression, kept after the widget
    # templates it was originally written against were removed.
    it "passes site through page -> section -> block" do
      revision.templates.create!(name: "block/sitecheck",
                                 source: %(<div class="b b-sitecheck">{{ site.name }}</div>))
      # A value this spec set, rather than whatever the site happens to be
      # called: the point is that `site` arrives at all.
      revision.site_settings.create!(key: "name", value: "Reached The Block")
      section = build_section(page: page)
      build_block(section: section, kind: "sitecheck")

      expect(renderer.body(page.reload)).to include("Reached The Block")
    end
  end

  it "raises a clear error naming the template, not \"internal\"" do
    section = build_section(page: page)
    build_block(section: section, kind: "text", content: "x")
    revision.templates.find_by(name: "section").destroy

    expect { renderer.body(page.reload) }.to raise_error(/section/)
  end

  # A block kind is only usable once a template renders it. Without this a kind
  # with no template renders as nothing at all -- content silently vanishing.
  it "refuses a block kind that has no template" do
    section = build_section(page: page)
    block = Block.new(section: section, revision: revision, kind: "nonesuch", content: "x")

    expect(block).not_to be_valid
    expect(block.errors.full_messages.first).to match(/no template/)
  end

  it "accepts a new kind as soon as its template exists" do
    revision.templates.create!(name: "block/scripture", source: "<blockquote>{{ block.content }}</blockquote>")
    section = build_section(page: page)

    block = Block.new(section: section, revision: revision, kind: "scripture", content: "Be steadfast")
    expect(block).to be_valid
    block.save!
    expect(renderer.body(page.reload)).to include("<blockquote>Be steadfast</blockquote>")
  end
end
