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
  STATUSES = %w[published draft].freeze

  # Assigned, not supplied. Every caller that set this by hand was a chance to
  # set it wrong, and the seeds set every photo to version 1 on every run.
  before_validation :assign_next_version, on: :create

  validates :human_name, :content_type, :sha256, presence: true
  validates :version, presence: true,
                      uniqueness: { scope: :human_name,
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
  validates :sha256, uniqueness: { scope: :human_name }

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

  def assign_next_version
    return if version.present? && self.class.where(human_name: human_name, version: version).none?

    self.version = (self.class.where(human_name: human_name).maximum(:version) || 0) + 1
  end

  # A reference is a PAIR -- the slug and the version -- so a page says exactly
  # which photograph it shows and a rollback restores the picture along with the
  # words. There is no "current": that was an inference, and inferences are what
  # made rolling back dishonest.
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
