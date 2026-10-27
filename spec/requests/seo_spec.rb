require "rails_helper"

# The parish's goal, in Mitch's words: that somebody searching "orthodox church
# near me" in Rochester finds us.
RSpec.describe "what a search engine is told", type: :request do
  before { build_page(slug: "home", title: "Saint John the Baptist Orthodox Church") }

  describe "the home page" do
    it "does not name the parish twice in its title" do
      get "/"

      title = response.body[%r{<title>([^<]*)</title>}, 1]
      expect(title).to eq("Saint John the Baptist Orthodox Church")
    end

    it "gives one canonical address" do
      get "/"

      expect(response.body).to include(%(<link rel="canonical" href="#{SiteDrop.new.url}/">))
    end

    # Two addresses serving identical content is the oldest self-inflicted
    # ranking problem there is.
    it "sends /home to /, permanently" do
      get "/home"

      expect(response).to have_http_status(:moved_permanently)
      expect(response.headers["Location"]).to end_with("/")
    end

    it "does not redirect / to itself for ever" do
      get "/"

      expect(response).to have_http_status(:ok)
    end
  end

  # Structured data used to be built in Ruby: the name, the address, "@type":
  # "Church", and service times filtered out of the ChurchTrac feed by title
  # patterns nobody could read. It is now a "head" template in the revision,
  # which the parish owns and can correct by asking.
  #
  # These specs therefore test the MECHANISM, not the content. Ruby is not
  # supposed to know this is a church.
  describe "what the parish says it is" do
    def head_of_home
      get "/"
      response.body[%r{<head>(.*?)</head>}m, 1].to_s
    end

    it "renders whatever the head template says" do
      Revision.live.templates.create!(
        name: "head",
        source: '<script type="application/ld+json">{"@type":"Thing","name":"{{ site.name }}"}</script>'
      )

      data = JSON.parse(head_of_home[%r{<script type="application/ld\+json">\s*(\{.*?\})\s*</script>}m, 1])
      expect(data["@type"]).to eq("Thing")
      expect(data["name"]).to be_present
    end

    it "renders nothing extra when a revision has no head template" do
      Revision.live.templates.where(name: "head").destroy_all

      expect(head_of_home).not_to include("application/ld+json")
    end

    # The head of every page. A mistake in it must lose the structured data,
    # not the site.
    it "survives a broken head template" do
      Revision.live.templates.create!(name: "head", source: "{{ site.nonexistent.deeply.wrong }}")

      get "/"
      expect(response).to have_http_status(:ok)
    end

    it "does not assert anything about churches in Ruby" do
      ruby = File.read(Rails.root.join("app/services/site/seo.rb"))
      body = ruby.lines.reject { |l| l.strip.start_with?("#") }.join

      expect(body).not_to include("Church")
      expect(body).not_to include("openingHoursSpecification")
      expect(body).not_to include("CalendarEvent")
    end
  end

  describe "sharing a link" do
    it "carries Open Graph tags" do
      get "/"

      expect(response.body).to include(%(<meta property="og:title"))
      expect(response.body).to include(%(<meta property="og:url"))
    end
  end

  describe "the sitemap" do
    it "lists the published pages, generated rather than kept as a file" do
      get "/sitemap.xml"

      expect(response.content_type).to include("xml")
      expect(response.body).to include("<loc>#{SiteDrop.new.url}/</loc>")
    end

    it "is named in robots.txt" do
      get "/robots.txt"

      expect(response.body).to include("Sitemap: #{SiteDrop.new.url}/sitemap.xml")
      expect(response.body).to include("Disallow: /*?preview=")
    end
  end

  # A draft is at a signed address and holds words the parish has not agreed to
  # publish. A link pasted into a chat is enough to get one crawled.
  describe "a draft" do
    let(:draft) { Revision.open_sandbox }

    it "is told not to be indexed" do
      get "/?preview=#{draft.preview_token}"

      expect(response.body).to include(%(<meta name="robots" content="noindex, nofollow">))
    end

    it "claims no canonical address of its own" do
      get "/?preview=#{draft.preview_token}"

      expect(response.body).not_to include("rel=\"canonical\"")
    end

    it "still gets a sensible title, because a person is looking at it" do
      get "/?preview=#{draft.preview_token}"

      expect(response.body).to include("<title>Saint John the Baptist Orthodox Church</title>")
    end
  end
end
