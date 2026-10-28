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

  scope :active, -> { where(active: true) }

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
end
