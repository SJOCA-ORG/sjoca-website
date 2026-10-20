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

  describe "the structured data" do
    def church
      get "/"
      JSON.parse(response.body[%r{<script type="application/ld\+json">\s*(\{.*?\})\s*</script>}m, 1])
    end

    it "says this is a church, with its address" do
      expect(church["@type"]).to eq("Church")
      expect(church.dig("address", "addressLocality")).to eq("Rochester")
      expect(church.dig("address", "postalCode")).to eq("14620")
    end

    it "names the OCA as the parent body" do
      expect(church.dig("parentOrganization", "name")).to eq("Orthodox Church in America")
    end

    # Taken from the calendar the parish already keeps, so they cannot drift
    # from what is published.
    it "carries the service times from the calendar" do
      CalendarEvent.create!(title: "Divine Liturgy", starts_at: 3.days.from_now.change(hour: 10),
                            recurring: true, source: "churchtrac", synced_at: Time.current)

      hours = church["openingHoursSpecification"]
      expect(hours).to be_present
      expect(hours.first["opens"]).to be_present
    end

    # Coordinates nobody checked put the pin in the wrong street.
    it "omits coordinates rather than guessing them" do
      expect(church["geo"]).to be_nil
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
