require "rails_helper"

# An organization ends up with several hostnames: a subdomain of the shared
# domain from the day it is created, and its own domain once somebody points the
# DNS. Both keep working. Both SERVING is a different matter -- search engines
# call it duplicate content, and people bookmark whichever they saw first and
# never move off it.
#
# So everything that is not the canonical host is a permanent redirect to it,
# and setting canonical_url at cutover is what makes the staging subdomain start
# forwarding. The same mechanism sends a bare domain to www.
RSpec.describe "one site, one address", type: :request, signed_out: true do
  let!(:org) do
    o = Organization.sole_tenant or raise "expected one organization"
    o.update!(canonical_url: "https://www.example.org")
    %w[www.example.org example.org sjoca.sayoursite.com].each { |h| o.add_host(h) }
    Organization.acting_as(o) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      revision.site_settings.create!(key: "name", value: "The Example Society")
      Page.create!(slug: "home", title: "Home", nav_title: "Home", revision: revision)
      Page.create!(slug: "contact", title: "Contact", nav_title: "Contact", revision: revision)
    end
    o
  end

  # Off in development and test unless asked for: reaching the app by whatever
  # name you typed matters more locally than canonicalising it.
  around do |example|
    was = Rails.application.config.x.enforce_canonical_host
    Rails.application.config.x.enforce_canonical_host = true
    example.run
    Rails.application.config.x.enforce_canonical_host = was
  end

  it "serves the canonical host without redirecting" do
    host! "www.example.org"
    get "/"
    expect(response).to have_http_status(:ok)
  end

  it "sends the bare domain to www, permanently" do
    host! "example.org"
    get "/"
    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("https://www.example.org/")
  end

  # The one that makes cutover a one-field change: the address an organization
  # lived at while it was being built keeps working, as a forward.
  it "sends the shared-domain subdomain to the organization's own domain" do
    host! "sjoca.sayoursite.com"
    get "/"
    expect(response).to redirect_to("https://www.example.org/")
  end

  it "keeps the path and the query string" do
    host! "example.org"
    get "/contact?from=bulletin"
    expect(response.location).to eq("https://www.example.org/contact?from=bulletin")
  end

  describe "the guards" do
    # A 301 on a POST loses the body, and a browser is entitled to turn the
    # retry into a GET -- which would silently drop whatever was submitted.
    it "does not redirect anything but GET and HEAD" do
      host! "example.org"
      post admin_login_path, params: { session: { email: "nobody@example.org", password: "x" } }
      expect(response).not_to have_http_status(:moved_permanently)
    end

    # A typo in canonical_url would otherwise take a site off the air by
    # sending every request somewhere that does not answer.
    it "does nothing when the canonical host is not one of this organization's" do
      org.update!(canonical_url: "https://typo.example.net")

      host! "example.org"
      get "/"

      expect(response).to have_http_status(:ok)
    end

    it "does nothing when the organization has no address of its own" do
      org.update_column(:canonical_url, nil)

      host! "example.org"
      get "/"

      expect(response).to have_http_status(:ok)
    end

    it "is off unless the deployment asks for it" do
      Rails.application.config.x.enforce_canonical_host = false

      host! "example.org"
      get "/"

      expect(response).to have_http_status(:ok)
    end
  end

  # Running into a loop here means every page of a customer's site is a loop,
  # so it is asserted rather than reasoned about.
  it "does not loop: the canonical host serves, and once is enough" do
    host! "example.org"
    get "/"
    expect(response).to have_http_status(:moved_permanently)

    destination = URI.parse(response.location)
    host! destination.host
    get destination.request_uri
    expect(response).to have_http_status(:ok)
  end
end
