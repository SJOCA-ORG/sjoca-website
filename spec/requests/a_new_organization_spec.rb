require "rails_helper"

# A blank organization becoming a working website.
#
# This is the path nobody walks twice. The first organization was built by hand
# over three weeks, and the second will be built by a stranger in an afternoon
# with nobody watching -- so the only honest way to know it works is to do it
# here, every run, from nothing.
#
# It is also where the architectural claim gets tested rather than asserted.
# "No semantic knowledge in Ruby" is unfalsifiable while the only site in
# existence is a church. A blank organization that renders a working page with
# none of this parish in it is the proof.
#
# When the operator console arrives this spec is its specification: creating an
# organization, installing a starter and inviting an owner should each replace a
# step below, and the assertions should not have to change.
RSpec.describe "a new organization", type: :request do
  # Everything a new organization needs, done the long way on purpose -- each
  # line here is a thing the console will have to do.
  def create_organization(name:, slug:, host:, settings: {})
    org = Organization.create!(name: name, slug: slug, canonical_url: "https://#{host}")
    org.add_host(host)

    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "first")
      DefaultTemplates.install!(revision)
      settings.each { |k, v| revision.site_settings.create!(key: k.to_s, value: v) }
      Page.create!(slug: "home", title: name, nav_title: "Home", revision: revision)
    end

    org
  end

  describe "the defaults it is built from" do
    # This caught a real one: {%# ... %} needs a # on every line, so a comment
    # added to the default header parsed in no organization at all. Nothing else
    # would have noticed until somebody created one.
    # DefaultTemplates.all, not TEMPLATES: `all` merges in bulletin.liquid and
    # bulletin_email.liquid from disk, and those are installed into every new
    # organization as well. Checking only the heredocs would have read like
    # checking the defaults while checking two thirds of them.
    it "every default template is valid Liquid" do
      broken = DefaultTemplates.all.filter_map do |name, source|
        begin
          Liquid::Template.parse(source)
          nil
        rescue Liquid::Error => e
          "#{name}: #{e.message}"
        end
      end

      expect(broken).to be_empty, "default templates that will not parse:\n  #{broken.join("\n  ")}"
    end

    it "installs them all into a fresh revision" do
      org = create_organization(name: "Woodwind Society", slug: "woodwind", host: "woodwind.example")

      Organization.acting_as(org) do
        installed = Revision.live.templates.pluck(:name)
        expect(installed).to include(*DefaultTemplates.all.keys)
        expect(installed.size).to eq(DefaultTemplates.all.size)
      end
    end
  end

  describe "the site it serves" do
    let!(:org) do
      create_organization(name: "Woodwind Society", slug: "woodwind", host: "woodwind.example",
                          settings: { name: "Woodwind Society", short_name: "Woodwind" })
    end

    it "answers on its own hostname" do
      host! "woodwind.example"
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Woodwind")
    end

    # The behavioural twin of no_parish_in_ruby_spec. That one reads the source;
    # this one reads what a visitor is actually served, which is the thing that
    # matters and the thing a source scan can always be one pattern short of.
    it "serves not one word of this parish" do
      host! "woodwind.example"
      get "/"

      found = response.body.scan(ThisParish::PATTERN).uniq
      expect(found).to be_empty,
        "a brand new organization's home page carries this parish: #{found.inspect}"
    end

    it "says nothing about churches in its structured data or its head" do
      host! "woodwind.example"
      get "/"
      expect(response.body).not_to match(/"@type"\s*:\s*"Church"/i)
    end
  end

  describe "the brand in the header" do
    it "uses the monogram when there is one" do
      create_organization(name: "Woodwind Society", slug: "w1", host: "w1.example",
                          settings: { name: "Woodwind Society", short_name: "Woodwind", brand: "WWS" })
      host! "w1.example"
      get "/"
      expect(response.body).to match(%r{site-header__brand[^>]*>\s*WWS\s*<})
    end

    it "falls back to the short name, then to the full name" do
      create_organization(name: "Woodwind Society", slug: "w2", host: "w2.example",
                          settings: { name: "Woodwind Society", short_name: "Woodwind" })
      host! "w2.example"
      get "/"
      expect(response.body).to match(%r{site-header__brand[^>]*>\s*Woodwind\s*<})

      create_organization(name: "Fife and Drum", slug: "w3", host: "w3.example",
                          settings: { name: "Fife and Drum" })
      host! "w3.example"
      get "/"
      expect(response.body).to match(%r{site-header__brand[^>]*>\s*Fife and Drum\s*<})
    end
  end

  # The trap this guards is already written down in SiteDrop::FALLBACK: for an
  # hour, an unconfigured site rendered THIS parish's name and address. A second
  # organization installing with no settings yet would have published them.
  describe "before anybody has configured it" do
    it "looks unconfigured rather than like somebody else" do
      create_organization(name: "Nothing Set Yet", slug: "blank", host: "blank.example")

      host! "blank.example"
      get "/"

      expect(response).to have_http_status(:ok)
      found = response.body.scan(ThisParish::PATTERN).uniq
      expect(found).to be_empty, "an unconfigured site shows this parish: #{found.inspect}"
    end
  end
end
