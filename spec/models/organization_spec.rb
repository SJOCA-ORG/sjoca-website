require "rails_helper"

# The account's own facts -- as distinct from the facts a website publishes,
# which are site_settings and version with the content. An organization can roll
# back its pages; it cannot roll back out of who owns the account or which clock
# its dates are in.
RSpec.describe Organization do
  # let! not let: two of these examples create a second organization, after
  # which sole_tenant correctly returns nil. Resolving it lazily would mean
  # resolving it too late.
  let!(:existing) { Organization.sole_tenant or raise "expected one organization" }

  describe "the product organization" do
    it "is nobody by default" do
      expect(Organization.the_product).to be_nil
    end

    it "can be exactly one" do
      existing.update!(product: true)
      expect(Organization.the_product).to eq(existing)
    end

    it "refuses a second, readably" do
      existing.update!(product: true)
      second = Organization.new(name: "Also", slug: "also", product: true)

      expect(second).not_to be_valid
      expect(second.errors[:product]).to include(/already set on another/)
    end

    # The validation exists to give a person a sentence. The index exists
    # because a seed, a console session or a migration will not read it.
    it "refuses a second in the DATABASE, not only in the model" do
      existing.update!(product: true)

      expect {
        ActiveRecord::Base.connection.execute(<<~SQL)
          INSERT INTO organizations (name, slug, active, product, time_zone, locale, created_at, updated_at)
          VALUES ('Sneaky', 'sneaky', true, true, 'UTC', 'en', now(), now())
        SQL
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "validations" do
    it "insists on a time zone Rails knows" do
      existing.time_zone = "America/Rochester"
      expect(existing).not_to be_valid
      expect(existing.errors[:time_zone].join).to match(/not a time zone/)
    end

    it "insists on a locale there are translations for" do
      existing.locale = "kw"
      expect(existing).not_to be_valid
    end

    it "accepts a blank contact but not a malformed one" do
      expect(existing.tap { |o| o.contact_email = "" }).to be_valid
      expect(existing.tap { |o| o.contact_email = "not-an-address" }).not_to be_valid
    end

    it "wants a slug that reads well in a log or a filename" do
      expect(Organization.new(name: "X", slug: "Has Spaces")).not_to be_valid
      expect(Organization.new(name: "X", slug: "second-parish")).to be_valid
    end
  end

  describe "hostnames" do
    it "normalises what it is given" do
      existing.add_host("  HTTPS://Example.COM:3000/some/path  ")
      expect(existing.hosts).to include("example.com")
    end

    # A hostname resolving to two organizations is not a conflict to settle at
    # request time, so it cannot be stored at all.
    it "cannot be claimed by two organizations" do
      existing.add_host("contested.example")
      other = Organization.create!(name: "Other", slug: "other")

      expect { other.add_host("contested.example") }
        .to raise_error(ActiveRecord::RecordInvalid, /already belongs/)
    end
  end

  # Rails refuses any Host header not in config.hosts. In production that list
  # IS this method, so an organization created through the operator console is
  # reachable the moment its hostname row exists -- with no deploy, which is the
  # whole point of a console that creates organizations.
  describe "which hostnames the app will answer on" do
    it "knows a hostname somebody has claimed" do
      existing.add_host("claimed.example")
      expect(Organization.known_host?("claimed.example")).to be(true)
    end

    it "does not know one nobody has" do
      expect(Organization.known_host?("someone-elses-domain.example")).to be(false)
    end

    it "does not care how it was capitalised or spaced" do
      existing.add_host("mixed.example")
      expect(Organization.known_host?("  MiXeD.Example  ")).to be(true)
    end

    it "says no to nothing at all, rather than raising" do
      expect(Organization.known_host?(nil)).to be(false)
      expect(Organization.known_host?("")).to be(false)
    end

    # A new organization is reachable without a deploy. Asserted end to end
    # because the claim is about two things agreeing -- the allowlist and the
    # router -- and either one alone would pass a narrower test.
    it "knows a hostname the moment an organization is created with it" do
      other = Organization.create!(name: "Brand New", slug: "brand-new")
      expect(Organization.known_host?("brandnew.example")).to be(false)

      other.add_host("brandnew.example")

      expect(Organization.known_host?("brandnew.example")).to be(true)
      expect(Organization.by_host("brandnew.example")).to eq(other)
    end
  end

  describe "acting_as" do
    it "puts the previous organization back" do
      other = Organization.create!(name: "Other", slug: "other")
      Current.organization = existing

      Organization.acting_as(other) { expect(Current.organization).to eq(other) }

      expect(Current.organization).to eq(existing)
    end

    # Otherwise one raised exception leaves the thread pointed at somebody
    # else's data for whatever runs on it next.
    it "puts it back even when the block raises" do
      other = Organization.create!(name: "Other", slug: "other")
      Current.organization = existing

      expect {
        Organization.acting_as(other) { raise "something went wrong" }
      }.to raise_error("something went wrong")

      expect(Current.organization).to eq(existing)
    end
  end

  describe "its address" do
    it "has no trailing slash, however it was typed" do
      existing.update!(canonical_url: "https://example.com/")
      expect(existing.canonical_url).to eq("https://example.com")
    end

    it "falls back to the deployment's setting when it has none" do
      existing.update_column(:canonical_url, nil)
      expect(existing.canonical_url).to eq(Organization.fallback_url)
    end
  end
end
