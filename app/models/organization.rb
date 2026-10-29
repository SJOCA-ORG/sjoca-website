# Whoever this website belongs to.
#
# One app, many organizations. An organization is NOT a parish -- a parish is
# one thing an organization can be, and a club, a school or a shop are others.
# Nothing in this class knows which; what an organization is lives in its own
# settings, templates, photographs and lessons, as rows it can edit.
#
# Everything a visitor or an editor touches is reached through here, by one of
# two routes: a hostname resolves to an organization, and every scoped model
# then filters on it. See BelongsToOrganization for the second half.
class Organization < ApplicationRecord
  has_many :organization_hosts, dependent: :destroy
  has_many :revisions, dependent: :destroy
  has_many :photos,    dependent: :destroy
  has_many :tags,      dependent: :destroy
  has_many :promises,  dependent: :destroy
  has_many :lessons,   dependent: :destroy
  has_many :fetched_pages, dependent: :destroy
  # Destroyed, not nullified, and the reason is worth keeping.
  #
  # :nullify was the instinct -- an account is a person, and a person does not
  # stop existing because an organization did. But a user row with no
  # organization and no application_admin violates the check constraint that
  # says everybody must be somewhere, so destroying an organization with
  # editors in it simply FAILED, with a PG::CheckViolation from four frames
  # down.
  #
  # And the instinct was wrong anyway. An editor account for an organization
  # that no longer exists cannot sign in anywhere -- may_act_in? refuses it at
  # every hostname -- while its email address, which is unique across the whole
  # system, goes on blocking that person from being invited to a different
  # organization. A ghost that locks the door behind it.
  #
  # Application administrators are untouched: their organization_id is null, so
  # this association never matched them in the first place.
  has_many :users, dependent: :destroy

  SLUG = /\A[a-z0-9][a-z0-9-]{0,40}\z/

  # A slug becomes a subdomain of the shared domain -- sjoca.example.com -- so
  # these are not merely ugly names, they are names that would take over a piece
  # of the system. Reserved now, while the cost is a validation. With customers
  # on the system it is a migration, a redirect, and a conversation with
  # somebody who has already printed their address on something.
  #
  # Grouped so the list can be argued with. A flat hundred words is a list
  # nobody reads before adding to.

  # Addresses the platform will want for itself. Some already exist; the rest
  # are cheaper to hold than to reclaim.
  RESERVED_PLATFORM = %w[
    about account accounts admin administrator affiliates api app apps auth
    billing blog careers changelog community console contact dashboard docs
    documentation feedback help id invoices jobs join learn legal login logout
    onboard partners pay press pricing privacy register roadmap security signin
    signout signup sso status support terms training trial try welcome www
  ].freeze

  # Mail. RFC 2142 names a set of mailboxes every domain is expected to answer,
  # and certificate authorities use several of them for domain validation --
  # which is why an organization must not be able to own one.
  RESERVED_MAIL = %w[
    abuse autoconfig autodiscover bounce bounces dkim dmarc email hostmaster
    imap inbox mail mailer mx noc noreply pop postmaster relay smtp spf
    webmaster webmail
  ].freeze

  # Names that software goes looking for on its own, without being asked.
  # wpad and isatap are the sharp ones: an operating system may fetch proxy
  # configuration from wpad.<domain>, so whoever owns that name can route other
  # people's traffic. They appear on every reserved-hostname list for that
  # reason and on no list of names anybody wanted.
  RESERVED_DISCOVERY = %w[
    isatap local localdomain localhost ns ns1 ns2 ns3 ns4 wpad
  ].freeze

  # Infrastructure, present and likely. Most of these will be real one day.
  RESERVED_INFRASTRUCTURE = %w[
    assets backup backups build cdn ci cron db deploy dev devops edge files
    ftp git grafana logs media metrics origin preview proxy qa queue repo
    sandbox secure sentry ssl staging static storage test uploads vpn worker
  ].freeze

  # Things this product in particular will want to serve.
  RESERVED_PRODUCT = %w[
    cms demo example examples gallery images img operator portal showcase
    starters templates themes
  ].freeze

  RESERVED_SLUGS = (
    RESERVED_PLATFORM + RESERVED_MAIL + RESERVED_DISCOVERY +
    RESERVED_INFRASTRUCTURE + RESERVED_PRODUCT
  ).sort.uniq.freeze

  validates :name, presence: true
  validates :slug, presence: true, format: { with: SLUG,
    message: "is lower case letters, numbers and hyphens — it appears in logs and filenames"
  }, uniqueness: true
  validates :slug, exclusion: {
    in: RESERVED_SLUGS,
    message: "is reserved — it would become a subdomain the system needs for itself"
  }

  validates :time_zone, presence: true
  # ActiveSupport::TimeZone[] accepts BOTH an IANA identifier ("Europe/Berlin")
  # and Rails' own short name ("Berlin"). An inclusion check against
  # TimeZone.all.map(&:name) accepts only the second -- which rejected
  # "America/New_York", the value config.time_zone is set to and the one the
  # migration had already written into the live row. A validation that makes
  # existing data invalid is worse than no validation: nothing fails until
  # somebody saves an unrelated change.
  validate :time_zone_is_one_that_exists
  validates :locale, presence: true,
                     inclusion: { in: -> (_) { I18n.available_locales.map(&:to_s) },
                                  message: "is not a locale this app has translations for" }
  validates :contact_email, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/,
                                      message: "does not look like an address" },
                            allow_blank: true
  validate :only_one_product_organization

  scope :active,   -> { where(active: true) }
  scope :product,  -> { where(product: true) }
  # A look to copy from, not somebody's website. Kept out of the accounts list
  # and out of anything that counts customers.
  scope :starters, -> { where(starter: true).order(:name) }
  scope :tenants,  -> { where(starter: false) }

  # This tool's own site. Where the operator console answers, and who owns the
  # page an unrecognised hostname gets. The only thing special about it.
  def self.the_product = product.first

  def self.by_host(host)
    return nil if host.blank?

    joins(:organization_hosts)
      .find_by(organization_hosts: { host: host.to_s.strip.downcase })
  end

  # The only organization, when there is exactly one.
  #
  # This is what keeps a single-organization install, the console, the seeds and
  # every rake task working without each of them having to announce who they are
  # first. The moment a second organization exists it returns nil, and anything
  # that has not said which organization it means gets nothing rather than
  # somebody else's data.
  #
  # So the forgiving behaviour disappears exactly when being forgiving would
  # start to be dangerous.
  # Starters are excluded deliberately. They are organizations so that a look
  # can be built by using the product, but they are not tenants -- and without
  # this, seeding the six of them would silently switch off the fallback that
  # the console, the seeds and every rake task rely on, on a machine with one
  # real site.
  def self.sole_tenant = tenants.limit(2).to_a.then { |rows| rows.one? ? rows.first : nil }

  # For an application administrator looking across the whole system, and for
  # migrations. Deliberately long and ugly to type: it is the only sanctioned
  # way past the scope, and it should read like a decision in a diff.
  def self.acting_as(organization)
    previous = Current.organization
    Current.organization = organization
    yield
  ensure
    Current.organization = previous
  end

  # Where this organization's website lives, with no trailing slash. Needed
  # wherever a link has nothing to be relative TO -- an email has no page, so
  # "/media/home-hero" in one resolves against the mail client and shows a
  # broken picture.
  DEFAULT_URL = "http://localhost:3000".freeze

  def canonical_url = super.presence&.sub(%r{/+\z}, "") || self.class.fallback_url

  # For the handful of callers that need an absolute address and may run with
  # no organization resolved -- a rake task, a job, the console.
  def self.current_url = Current.organization&.canonical_url || fallback_url

  def self.fallback_url = ENV.fetch("SITE_URL", DEFAULT_URL).sub(%r{/+\z}, "")

  # Is this hostname one somebody has claimed?
  #
  # Rails blocks any Host header not in config.hosts, and that list used to name
  # sjoca.org in config/environments/production.rb. Which worked for one
  # organization and quietly broke the whole point of the operator console: a
  # customer's domain added through it would be refused by Rails until somebody
  # edited a file and redeployed. The same per-organization-knowledge-in-Ruby
  # mistake as SITE_URL and the Rochester time zone, in the one place where the
  # symptom is "the site is down" rather than "the site is wrong".
  #
  # So the allowlist is the table the router already trusts. One indexed lookup
  # per request, on a column with a unique index.
  # Deliberately NOT rescued. If the database is unreachable this raises, and a
  # request that would have 500'd on the next line 500s here instead -- with an
  # error that says the database is down. Rescuing to false would answer
  # "Blocked host" for every request in the middle of a database outage, which
  # sends whoever is woken up to look at DNS.
  def self.known_host?(host)
    name = host.to_s.downcase.strip
    return false if name.empty?

    OrganizationHost.exists?(host: name)
  end

  def hosts = organization_hosts.order(:host).pluck(:host)

  def add_host(host)
    organization_hosts.create!(host: host.to_s.strip.downcase)
  end

  def to_s = name

  # Who to write to about the ACCOUNT, as opposed to the address the website
  # publishes. The website's own is a site setting and may be a general
  # office address; this one is a person who can act.
  def contact = contact_email.presence && [contact_name.presence, contact_email].compact

  private

  # Also a partial unique index -- index_organizations_on_the_one_product --
  # because "exactly one" survives a validation right up until a seed or a
  # console session sets a second. This exists to give the person a readable
  # error before the database gives them an unreadable one.
  def time_zone_is_one_that_exists
    return if time_zone.blank?
    return if ActiveSupport::TimeZone[time_zone].present?

    errors.add(:time_zone, "is not a time zone — try an IANA name like Europe/Berlin")
  end

  def only_one_product_organization
    return unless product?

    taken = self.class.product.where.not(id: id).exists?
    errors.add(:product, "is already set on another organization") if taken
  end
end
