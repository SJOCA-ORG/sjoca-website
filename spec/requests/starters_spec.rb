require "rails_helper"

# Every starter, installed for real and then looked at.
#
# A starter is the first thing a customer sees, built by somebody who will never
# meet them, in files nobody runs until an organization is created. So each one
# is installed into a fresh organization here and the resulting site is
# requested -- not parsed, not stubbed, requested -- on every run.
#
# The specific failures this is looking for are the ones that are invisible
# until the day somebody creates an organization: a Liquid comment that does not
# parse, a block kind with no template, a page that renders three bytes, and a
# starter quietly carrying this parish.
RSpec.describe "the starters", type: :request, signed_out: true do
  def organization_from(starter, host:)
    org = Organization.create!(name: "The Test Society", slug: "test-society-#{starter.name}",
                               canonical_url: "https://#{host}")
    org.add_host(host)
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "First")
      starter.install!(revision)
      revision.site_settings.find_or_initialize_by(key: "name").update!(value: "The Test Society")
    end
    org
  end

  it "finds the starters on disk" do
    expect(Starter.all.map(&:name)).to include("plain")
    expect(Starter.all.size).to be >= 3
  end

  it "falls back to the default when asked for one that does not exist" do
    expect(Starter.find_or_default("no-such-look").name).to eq(Starter::DEFAULT)
    expect(Starter.find_or_default(nil).name).to eq(Starter::DEFAULT)
  end

  # The starter name reaches this from a form, and is used to build a path.
  it "refuses a name that is a path rather than a name" do
    expect(Starter.find("../../etc")).to be_nil
    expect(Starter.find("plain/../plain")).to be_nil
  end

  Starter.all.each do |starter|
    describe starter.name do
      let(:host) { "#{starter.name}.example" }

      it "has a title and a sentence saying what it is for" do
        expect(starter.title).to be_present
        expect(starter.summary).to be_present
      end

      it "installs and serves its home page" do
        organization_from(starter, host: host)

        host! host
        get "/"

        expect(response).to have_http_status(:ok)
        # Three bytes is what an empty page renders as, and it looks like a
        # working site until somebody opens it.
        expect(response.body.length).to be > 500
      end

      it "serves every page it claims to install" do
        org = organization_from(starter, host: host)
        slugs = Organization.acting_as(org) { Page.in_revision(Revision.live).pluck(:slug) }
        expect(slugs).to include("home")

        host! host
        slugs.each do |slug|
          get(slug == "home" ? "/" : "/#{slug}")
          expect(response).to have_http_status(:ok), "#{starter.name} cannot serve /#{slug}"
        end
      end

      # THE ONE THAT WAS MISSING.
      #
      # The gathering starter's section template invented its own structure --
      # section.blocks instead of section.columns -- and rendered every band
      # perfectly with nothing inside it. Liquid does not complain about a loop
      # over nothing, so the page came out plausible and empty, and every spec
      # here passed: the templates existed, the page was 5KB of shell, and no
      # block kind was missing a template.
      #
      # What none of them asked was whether the words in the starter reached
      # the page.
      it "puts its own words on the page" do
        organization_from(starter, host: host)
        host! host

        starter.manifest.fetch("pages", []).each do |page|
          get(page["slug"] == "home" ? "/" : "/#{page['slug']}")
          text = response.body.gsub(/<[^>]+>/, " ").gsub(/&#?\w+;/, " ").gsub(/\s+/, " ")

          expect(text).to include(page["hero_heading"].strip) if page["hero_heading"].present?

          (page["sections"] || []).each do |section|
            (section["blocks"] || []).each do |block|
              # The first line, shortened: enough to be distinctive, short
              # enough to survive wrapping and entity escaping.
              wanted = block["content"].to_s.strip.lines.first.to_s.strip[0, 30]
              next if wanted.blank?

              expect(text).to include(wanted),
                "#{starter.name} /#{page['slug']} does not show #{wanted.inspect}"
            end
          end
        end
      end

      it "leaves no block without a template to render it" do
        org = organization_from(starter, host: host)

        Organization.acting_as(org) do
          kinds = Block.where(revision: Revision.live).distinct.pluck(:kind)
          templates = Revision.live.templates.pluck(:name)
          missing = kinds.reject { |k| templates.include?("block/#{k}") }
          expect(missing).to be_empty, "#{starter.name} uses #{missing.inspect} with no template"
        end
      end

      it "every template it installs is valid Liquid" do
        org = organization_from(starter, host: host)

        broken = Organization.acting_as(org) do
          Revision.live.templates.filter_map do |t|
            begin
              Liquid::Template.parse(t.source)
              nil
            rescue Liquid::Error => e
              "#{t.name}: #{e.message}"
            end
          end
        end

        expect(broken).to be_empty
      end

      # The behavioural half of the source scan. A scan can always be one
      # pattern short -- a monogram matches nothing a word-based pattern looks
      # for, which is how SJTB survived in the default header.
      it "serves not one word of this parish" do
        org = organization_from(starter, host: host)
        slugs = Organization.acting_as(org) { Page.in_revision(Revision.live).pluck(:slug) }

        host! host
        slugs.each do |slug|
          get(slug == "home" ? "/" : "/#{slug}")
          found = response.body.scan(ThisParish::PATTERN).uniq
          expect(found).to be_empty, "#{starter.name} /#{slug} carries #{found.inspect}"
        end
      end
    end
  end

  # What the operator console actually does with one.
  describe "creating an organization from one" do
    it "uses the starter that was asked for, and says so in the log" do
      product = Organization.sole_tenant
      product.update!(product: true, canonical_url: "https://builder.example")
      product.add_host("builder.example")
      operator = User.create!(email: "operator@example.com", password: "Passw0rd!",
                              role: "superadmin", application_admin: true, organization: nil)

      host! "builder.example"
      post admin_login_path, params: { session: { email: operator.email, password: "Passw0rd!" } }

      post operator_organizations_path, params: {
        name: "Woodwind Society", slug: "woodwind", host: "woodwind.example",
        owner_email: "owner@woodwind.example", starter: "noticeboard"
      }

      org = Organization.find_by(slug: "woodwind")
      expect(org).to be_present

      Organization.acting_as(org) do
        slugs = Page.in_revision(Revision.live).pluck(:slug)
        expect(slugs).to include("calendar")       # the noticeboard's, not the plain one's
      end

      expect(OperatorAction.find_by(action: "created").detail).to include("noticeboard")
    end

    # The organization's own name must win over whatever the starter called it.
    it "names the site after the organization, not after the starter" do
      result = Operator::CreateOrganization.new(
        name: "Fife and Drum", slug: "fife", host: "fife.example",
        owner_email: "owner@fife.example", starter: "gathering"
      ).call

      expect(result).to be_ok
      host! "fife.example"
      get "/"
      expect(response.body).to include("Fife and Drum")
    end
  end
end
