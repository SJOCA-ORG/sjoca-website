require "rails_helper"

# Making one organization's website from another's.
#
# This is how a customer's site will be created: a starter is an organization,
# and creating a site copies its live revision across. So the thing to prove is
# not that rows appeared, but that the SECOND SITE RENDERS THE SAME PAGES as
# the first -- and that nothing about the first organization's account came
# with them.
RSpec.describe "copying a website into another organization" do
  let!(:source) do
    org = Organization.sole_tenant or raise "expected one organization"
    org.update!(starter: true, contact_email: "us@example.com",
                canonical_url: "https://source.example")
    org.add_host("source.example")
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      revision.site_settings.create!(key: "name", value: "The Source")
      revision.site_settings.create!(key: "brand", value: "SRC")
      revision.templates.find_or_initialize_by(name: "header").update!(source: "<header>MINE</header>")

      page = Page.create!(slug: "home", title: "Home", nav_title: "Home", revision: revision)
      section = page.sections.create!(style: "plain", revision: revision)
      section.blocks.create!(kind: "heading", content: "A heading", revision: revision)
      section.blocks.create!(kind: "text", content: "Some words", revision: revision)
      Page.create!(slug: "about", title: "About", nav_title: "About", revision: revision)

      bytes = "PNG-source-hero"
      Photo.create!(human_name: "hero", content_type: "image/png", data: bytes,
                    byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                    status: "published", version: 1)
      User.create!(email: "editor@source.example", password: "Passw0rd!", role: "superadmin")
    end
    org
  end

  let(:target) { Organization.create!(name: "The Target", slug: "target") }

  def live_of(org) = Organization.acting_as(org) { Revision.live }

  describe "what travels" do
    it "brings the pages, sections and blocks" do
      live_of(source).copy_into(target)

      Organization.acting_as(target) do
        revision = Revision.live
        expect(Page.in_revision(revision).pluck(:slug)).to match_array(%w[home about])
        expect(Block.where(revision: revision).pluck(:content)).to include("A heading", "Some words")
      end
    end

    it "brings the templates, including one the source had changed" do
      live_of(source).copy_into(target)

      Organization.acting_as(target) do
        expect(Revision.live.templates.find_by(name: "header").source).to eq("<header>MINE</header>")
        expect(Revision.live.templates.count).to eq(DefaultTemplates.all.size)
      end
    end

    it "brings the stylesheet and the settings" do
      live_of(source).copy_into(target)

      Organization.acting_as(target) do
        expect(ThemeAsset.css_for(Revision.live).length).to be > 10_000
        expect(SiteSetting.for(Revision.live)["brand"]).to eq("SRC")
      end
    end

    # Within one organization a draft shares its photographs with the live
    # revision. Across organizations that would be a site depending on somebody
    # else's picture, which a stranger could replace or delete.
    it "brings the photographs, as copies with their own rows" do
      live_of(source).copy_into(target)

      mine   = Organization.acting_as(source) { Photo.find_by(human_name: "hero") }
      theirs = Organization.acting_as(target) { Photo.find_by(human_name: "hero") }

      expect(theirs).to be_present
      expect(theirs.id).not_to eq(mine.id)
      expect(theirs.sha256).to eq(mine.sha256)
      expect(theirs.data).to eq(mine.data)
      expect(theirs.organization_id).to eq(target.id)
    end
  end

  describe "what does not travel" do
    before { live_of(source).copy_into(target) }

    it "leaves the people behind" do
      expect(User.where(organization_id: target.id)).to be_empty
    end

    it "leaves the hostnames behind" do
      expect(target.reload.hosts).to be_empty
    end

    it "leaves the account's own details behind" do
      expect(target.reload.contact_email).to be_nil
      expect(target.canonical_url).not_to eq("https://source.example")
    end

    it "does not make the new organization a starter too" do
      expect(target.reload.starter).to be(false)
    end
  end

  # The claim that matters, and the only one a person would check: the copy is
  # the same website.
  describe "the copy renders the same site", type: :request do
    it "serves identical pages from the new organization's hostname" do
      live_of(source).copy_into(target)
      target.update!(canonical_url: "https://target.example")
      target.add_host("target.example")
      Organization.acting_as(target) do
        Revision.live.site_settings.find_by(key: "name").update!(value: "The Source")
      end

      host! "source.example"
      get "/"
      from_source = without_row_ids(response.body)

      host! "target.example"
      get "/"
      from_target = without_row_ids(response.body)

      # Byte-identical apart from data-block, which carries the database id and
      # cannot be the same for two rows. Normalised rather than loosened: the
      # test still fails on a single different character of markup, which is
      # how it would catch a template or a setting that did not come across.
      expect(from_target).to eq(from_source)
    end

    # Three things are normalised, and each is a fact about the copy rather
    # than a loss in it.
    #
    #   data-block, and any id="thing-123" -- a database id, which cannot be
    #   equal for two rows. Found by round-tripping the real site: the fixture
    #   here has no block that puts its id in an element id, so the first
    #   version of this normaliser passed while three real pages differed.
    #
    #   The canonical and og:url tags, which carry each organization's OWN
    #   address. An account's address does not travel with a website.
    #
    #   Embedded JSON from a data source, which is fetched when the page is
    #   rendered. The DEFINITION travels; what it returned a moment ago does not,
    #   and should not.
    def without_row_ids(html)
      html.gsub(/data-block="\d+"/, 'data-block=""')
          .gsub(/id="([a-z-]+)-\d+"/, 'id="\\1"')
          .gsub(%r{<script type="application/json"[^>]*>.*?</script>}m, "<json/>")
          .gsub(%r{https?://(?:source|copy|target)\.example}, "https://site.example")
    end
  end

  describe "copying twice" do
    it "does not duplicate the photographs" do
      live_of(source).copy_into(target)
      expect { live_of(source).copy_into(target, state: "draft") }
        .not_to change { Organization.acting_as(target) { Photo.count } }
    end
  end

  # A starter is not a tenant. Seeding six of them must not switch off the
  # single-organization fallback that the console and the seeds rely on.
  describe "starters are not counted as tenants" do
    it "is still the only tenant with the starters beside it" do
      source.update!(starter: false)
      starters = Organization.starters.count
      expect(starters).to be >= 6, "the suite should have seeded the sample sites"

      expect(Organization.count).to eq(starters + 1)
      expect(Organization.sole_tenant).to eq(source)
    end
  end
end
