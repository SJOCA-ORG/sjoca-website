require "rails_helper"

# config.time_zone is "America/New_York" -- one organization's clock, applied to
# every organization's dates. That was invisible while there was one of them,
# and would have stayed invisible: a club in Berlin does not get an error, it
# gets Rochester's Tuesday.
#
# So each request runs in its own organization's zone and locale.
RSpec.describe "an organization's clock and language", type: :request do
  def organization(slug:, host:, time_zone:, locale: "en")
    org = Organization.create!(name: slug.titleize, slug: slug, time_zone: time_zone,
                               locale: locale, canonical_url: "https://#{host}")
    org.add_host(host)
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      revision.site_settings.create!(key: "name", value: slug.titleize)
      Page.create!(slug: "home", title: slug.titleize, nav_title: "Home", revision: revision)
    end
    org
  end

  # Captured during rendering, which is inside the around_action -- by the time
  # process_action finishes, the zone has already been put back.
  def zone_while_rendering
    seen = nil
    sub = ActiveSupport::Notifications.subscribe("render_template.action_view") do
      seen ||= [Time.zone.name, I18n.locale]
    end
    yield
    seen
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  it "renders in the organization's own time zone" do
    organization(slug: "berlin-club", host: "berlin.example", time_zone: "Europe/Berlin")
    organization(slug: "denver-club", host: "denver.example", time_zone: "America/Denver")

    host! "berlin.example"
    expect(zone_while_rendering { get "/" }.first).to eq("Europe/Berlin")

    host! "denver.example"
    expect(zone_while_rendering { get "/" }.first).to eq("America/Denver")
  end

  # Time.use_zone restores it, which matters because the thread is reused. A
  # before_action that only set it would leave the next request -- possibly
  # another organization's -- running on this one's clock.
  it "puts the process's own zone back afterwards" do
    organization(slug: "berlin-club", host: "berlin.example", time_zone: "Europe/Berlin")
    before = Time.zone.name

    host! "berlin.example"
    get "/"

    expect(Time.zone.name).to eq(before)
  end

  it "carries the organization's locale while rendering" do
    organization(slug: "plain-club", host: "plain.example", time_zone: "UTC")

    host! "plain.example"
    expect(zone_while_rendering { get "/" }.last).to eq(:en)
  end
end
