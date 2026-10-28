# A parish photograph, stored as bytes in the database rather than on disk or in
# object storage. The first batch came across from the Google Sites site; new
# ones are uploaded.
#
# Two reasons for bytes-in-the-table:
#   1. A pg_dump is then a complete copy. Pulling production down for local
#      development brings the images with it, with no blob syncing to get wrong.
#   2. After cutover the Google Site goes away, so this table becomes the
#      parish's only copy of these photos. One thing to back up, not two.
#
# Versioning: rows are append-only. Several rows may share a human_name, each
# with its OWN version, and a page refers to the pair. Replacing a photo means
# inserting a new row, which leaves the old one intact and recoverable.
#
# The pair must be unique or it identifies nothing. It was not enforced, and
# three different photographs ended up as "leadership-dn-mitch version 1" --
# one of an ordination, two at the altar. find_version does a find_by, so the
# deployed site showed one of them and a developer machine showed another, from
# the same reference. Hence the unique index, and hence the version being
# assigned here rather than by whoever happens to be inserting.
class Photo < ApplicationRecord
  include BelongsToOrganization
  STATUSES = %w[published draft].freeze

  # Assigned, not supplied. Every caller that set this by hand was a chance to
  # set it wrong, and the seeds set every photo to version 1 on every run.
  before_validation :assign_next_version, on: :create

  # organization_id is named in every uniqueness scope below, and must be.
  # Rails' uniqueness validator calls klass.unscoped (activerecord-8.1.4,
  # validations/uniqueness.rb:113), so it does NOT see the default_scope that
  # organization-scoping relies on. Leave it out and the check runs across every
  # organization in the system: a second organization is told its photograph
  # name is taken, which is both wrong and a way of asking what the first one
  # has got.
  validates :human_name, :content_type, :sha256, presence: true
  validates :version, presence: true,
                      uniqueness: { scope: %i[organization_id human_name],
                                    message: "already exists for this name" }

  # A photograph has to BE one. A row containing the eight bytes "NEWBYTES"
  # passed every check here -- it had a name, a content type and some data --
  # and five pages pointed at it, including the home page of the published
  # revision. The live site served an 8-byte PNG as its hero for three days.
  validate :data_is_really_an_image, on: :create

  private

  def data_is_really_an_image
    return if data.blank?
    # Not every test wants a real JPEG in hand; this is about rows that reach a
    # page, so the check applies to anything big enough to be a photograph.
    return if data.bytesize < 64 && !Rails.env.production?
    return if Admin::ImageTools.identify(data).present?

    errors.add(:data, "is not an image any browser could display")
  end

  public
  validates :data, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :sha256, uniqueness: { scope: %i[organization_id human_name] }

  has_many :photo_tags, dependent: :destroy
  has_many :tags, through: :photo_tags

  scope :published, -> { where(status: "published") }

  # Uploaded, as opposed to created by a crop, an import or a seed. "Anything
  # you would like done with those?" has to mean the four that just arrived,
  # not the four most recently written rows.
  scope :uploaded,  -> { where.not(uploaded_at: nil).order(uploaded_at: :desc) }
  scope :recently_uploaded, ->(since = 2.hours.ago) { uploaded.where(uploaded_at: since..) }
  scope :tagged, ->(*names) { joins(:tags).where(tags: { name: names.flatten.map { |n| Tag.canonical(n) } }).distinct }

  # Tagging is additive and says what it did, because "tag these as clergy" on
  # twenty photographs should report twenty, not fail silently on the three
  # that already had it.
  def tag_with(*labels)
    added = labels.flatten.filter_map { |l| Tag.for(l) }
                  .reject { |t| tags.include?(t) }
    added.each { |t| photo_tags.create!(tag: t) }
    tags.reload
    added
  end

  def untag(*labels)
    wanted = labels.flatten.map { |l| Tag.canonical(l) }
    removed = tags.select { |t| wanted.include?(t.name) }
    photo_tags.where(tag_id: removed.map(&:id)).destroy_all
    tags.reload
    removed
  end

  def tag_labels = tags.order(:label).pluck(:label)

  def versions_count = self.class.where(human_name: human_name).count

  # A name PhotoIntake made up from a filename, which no page should point at.
  # Matching "new-" alone would keep nagging about a photograph somebody
  # deliberately called "new-years-2026".
  PROVISIONAL = /\Anew-(upload|img|dsc|dscn|pxl|photo|image|screenshot|\d)/i

  def provisional_name? = PROVISIONAL.match?(human_name.to_s)

  def assign_next_version
    return if version.present? && self.class.where(human_name: human_name, version: version).none?

    self.version = (self.class.where(human_name: human_name).maximum(:version) || 0) + 1
  end

  # A reference is a PAIR -- the slug and the version -- so a page says exactly
  # which photograph it shows and a rollback restores the picture along with the
  # words. There is no "current": that was an inference, and inferences are what
  # made rolling back dishonest.
  # Everything about a photograph EXCEPT the picture itself.
  #
  # The bytes live in this table, which is the whole point -- a pg_dump is then
  # a complete copy of the site. The cost is that `Photo.published` drags every
  # image out of the database along with its name.
  #
  # On a laptop that is invisible: Postgres is the same machine. On the server
  # it is not. The library page loaded 200 rows to print 200 names, which meant
  # pulling 147 MB across the Atlantic, and took a minute to appear.
  #
  # Anything that lists or searches photographs wants this. Anything that SHOWS
  # one does not -- and calling .data on one of these raises rather than quietly
  # returning nothing, which is the behaviour you want from a mistake.
  #
  # ONE SHARP EDGE: .count on a relation carrying a multi-column select builds
  # SELECT COUNT(id, human_name, ...), which is not a function that exists, and
  # Postgres says so at some length. Use .count(:id), or count before scoping:
  #
  #   Photo.published.listing.count        # raises
  #   Photo.published.listing.count(:id)   # fine
  #   Photo.published.count                # fine, and cheap -- COUNT reads no bytes
  #
  # The real fix is for the bytes to live in their own table, so none of this
  # needs thinking about. That is a migration for a quieter week; see TODO.
  def self.listing = select(column_names - ["data"])

  def self.find_version(human_name, version)
    return nil if human_name.blank? || version.blank?

    published.find_by(human_name: human_name, version: version)
  end

  # Only for choosing a version to pin, never for rendering.
  def self.newest(human_name)
    published.where(human_name: human_name).order(version: :desc, id: :desc).first
  end

  # Every version of a name, for an editor deciding which to point at.
  def self.choices(human_name)
    versions_of(human_name).map { |p| { version: p.version, added: p.created_at.to_date.to_s,
                                        bytes: p.byte_size } }
  end

  # Every version of a name, newest first. For the Phase 2 history view.
  def self.versions_of(human_name)
    where(human_name: human_name).order(created_at: :desc, id: :desc)
  end

  def self.digest(bytes) = Digest::SHA256.hexdigest(bytes)
end
