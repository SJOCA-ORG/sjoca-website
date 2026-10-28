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
  has_many :users, dependent: :nullify

  SLUG = /\A[a-z0-9][a-z0-9-]{0,40}\z/

  validates :name, presence: true
  validates :slug, presence: true, format: { with: SLUG,
    message: "is lower case letters, numbers and hyphens — it appears in logs and filenames"
  }, uniqueness: true

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

  scope :active,  -> { where(active: true) }
  scope :product, -> { where(product: true) }

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
  def self.sole_tenant = all.limit(2).to_a.then { |rows| rows.one? ? rows.first : nil }

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
