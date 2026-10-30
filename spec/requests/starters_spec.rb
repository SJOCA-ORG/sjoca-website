require "rails_helper"

# Every sample site, as it actually exists: an organization, seeded out of
# db/seeds/starters, serving on its own hostname.
#
# These were folders of YAML read by an installer. They are organizations now,
# which means a look is built by USING the product -- asked for in words,
# previewed, looked at -- and can hold photographs, which a manifest cannot.
# Creating a customer's website is a copy of one of these.
#
# The failures this is looking for are the ones that are invisible until
# somebody creates an organization: a template that does not parse, a block
# kind with no template, a page that renders three bytes, a site with no
# stylesheet, and a starter quietly carrying this parish.
RSpec.describe "the starters", type: :request, signed_out: true do
  # Read from the FOLDER at load time, because the database is seeded after
  # these example groups are defined. The organization is looked up inside each
  # example, by which time it is there.
  NAMES = Dir.children(Rails.root.join("db/seeds/starters")).sort.freeze

  def starter(name) = Organization.find_by!(slug: "starter-#{name}")

  it "has the sample sites from the repository" do
    expect(NAMES).to include("plain")
    expect(NAMES.size).to be >= 3
    expect(Organization.starters.count).to eq(NAMES.size)
  end

  it "offers one by default, and falls back to it when asked for nothing" do
    expect(Starters.chosen(nil).slug).to eq(Starters::DEFAULT)
    expect(Starters.chosen("no-such-look").slug).to eq(Starters::DEFAULT)
  end

  it "keeps them out of the count of tenants" do
    expect(Organization.tenants.map(&:slug)).not_to include(*Organization.starters.map(&:slug))
  end

  NAMES.each do |name|
    describe name do
      let(:organization) { starter(name) }
      let(:host) { "#{name}-starter.localhost" }

      it "has a hostname of its own, so it can be looked at" do
        expect(organization.hosts).to include(host)
      end

      it "serves its home page" do
        host! host
        get "/"

        expect(response).to have_http_status(:ok)
        # Three bytes is what an empty page renders as, and it looks like a
        # working site until somebody opens it.
        expect(response.body.length).to be > 500
      end

      it "serves every page it has" do
        slugs = Organization.acting_as(organization) { Page.in_revision(Revision.live).pluck(:slug) }
        expect(slugs).to include("home")

        host! host
        slugs.each do |slug|
          get(slug == "home" ? "/" : "/#{slug}")
          expect(response).to have_http_status(:ok), "#{name} cannot serve /#{slug}"
        end
      end

      # The fault that produced six screenshots of unstyled HTML: a site with
      # templates and no stylesheet. The link was in the markup; nothing
      # followed it.
      it "serves a stylesheet with the house style in it" do
        host! host
        get "/"
        href = response.body[/<link[^>]+rel="stylesheet"[^>]+href="([^"]+)"/, 1]
        expect(href).to be_present, "#{name} links no stylesheet at all"

        get href
        expect(response).to have_http_status(:ok)
        expect(response.body.length).to be > 10_000
        expect(response.body).to include(".band", ".hero")
      end

      it "leaves no block without a template to render it" do
        Organization.acting_as(organization) do
          kinds = Block.where(revision: Revision.live).distinct.pluck(:kind)
          templates = Revision.live.templates.pluck(:name)
          missing = kinds.reject { |k| templates.include?("block/#{k}") }
          expect(missing).to be_empty, "#{name} uses #{missing.inspect} with no template"
        end
      end

      it "every template it has is valid Liquid" do
        broken = Organization.acting_as(organization) do
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

      # Every photograph it claims is one it can serve. A starter arriving with
      # a broken image is worse than one arriving with none.
      it "serves every photograph it carries" do
        photos = Organization.acting_as(organization) { Photo.pluck(:human_name, :version) }

        host! host
        photos.each do |human_name, version|
          get "/media/#{human_name}/#{version}"
          expect(response).to have_http_status(:ok), "#{name} cannot serve #{human_name}"
        end
      end

      # The behavioural half of the source scan. A scan can always be one
      # pattern short -- a monogram matches nothing a word-based pattern looks
      # for, which is how SJTB survived in the default header.
      it "serves not one word of this parish" do
        slugs = Organization.acting_as(organization) { Page.in_revision(Revision.live).pluck(:slug) }

        host! host
        slugs.each do |slug|
          get(slug == "home" ? "/" : "/#{slug}")
          found = response.body.scan(ThisParish::PATTERN).uniq
          expect(found).to be_empty, "#{name} /#{slug} carries #{found.inspect}"
        end
      end
    end
  end

  describe "creating an organization from one" do
    it "copies the look that was asked for, and says so in the log" do
      product = Organization.sole_tenant
      product.update!(product: true, canonical_url: "https://builder.example")
      product.add_host("builder.example")
      operator = User.create!(email: "operator@example.com", password: "Passw0rd!",
                              role: "superadmin", application_admin: true, organization: nil)

      host! "builder.example"
      post admin_login_path, params: { session: { email: operator.email, password: "Passw0rd!" } }
      post operator_organizations_path, params: {
        name: "Woodwind Society", slug: "woodwind", host: "woodwind.example",
        owner_email: "owner@woodwind.example", starter: "starter-noticeboard"
      }

      org = Organization.find_by(slug: "woodwind")
      expect(org).to be_present

      from_starter = Organization.acting_as(starter("noticeboard")) do
        Page.in_revision(Revision.live).pluck(:slug).sort
      end
      theirs = Organization.acting_as(org) { Page.in_revision(Revision.live).pluck(:slug).sort }
      expect(theirs).to eq(from_starter)

      expect(OperatorAction.find_by(action: "created").detail).to include("Noticeboard")
    end

    it "brings the starter's photographs with it" do
      result = Operator::CreateOrganization.new(
        name: "Fife and Drum", slug: "fife", host: "fife.example",
        owner_email: "owner@fife.example", starter: "starter-studio"
      ).call
      expect(result).to be_ok

      mine   = Organization.acting_as(starter("studio"))  { Photo.order(:human_name).pluck(:human_name, :sha256) }
      theirs = Organization.acting_as(result.organization) { Photo.order(:human_name).pluck(:human_name, :sha256) }
      expect(theirs).to eq(mine)
      expect(theirs.size).to be >= 1
    end

    it "names the site after the organization, not after the starter" do
      result = Operator::CreateOrganization.new(
        name: "Fife and Drum", slug: "fife", host: "fife.example",
        owner_email: "owner@fife.example", starter: "starter-gathering"
      ).call

      expect(result).to be_ok
      host! "fife.example"
      get "/"
      expect(response.body).to include("Fife and Drum")
      expect(response.body).not_to include("Gathering Example")
    end
  end
end
