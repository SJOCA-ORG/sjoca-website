# An image carried over from the Google Sites site, stored as bytes in the
# database rather than on disk or in object storage.
#
# Two reasons for bytes-in-the-table:
#   1. A pg_dump is then a complete copy. Pulling production down for local
#      development brings the images with it, with no blob syncing to get wrong.
#   2. After cutover the Google Site goes away, so this table becomes the
#      parish's only copy of these photos. One thing to back up, not two.
#
# Versioning: rows are append-only. Several rows may share a human_name; the
# newest published one wins. Replacing a photo means inserting a new row, which
# leaves the old one intact and recoverable.
class LegacyAsset < ApplicationRecord
  STATUSES = %w[published draft].freeze

  validates :human_name, :content_type, :sha256, presence: true
  validates :data, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :sha256, uniqueness: { scope: :human_name }

  scope :published, -> { where(status: "published") }

  # The asset currently shown for this name.
  def self.current(human_name)
    published.where(human_name: human_name).order(created_at: :desc, id: :desc).first
  end

  # Every version of a name, newest first. For the Phase 2 history view.
  def self.versions_of(human_name)
    where(human_name: human_name).order(created_at: :desc, id: :desc)
  end

  def self.digest(bytes) = Digest::SHA256.hexdigest(bytes)
end
