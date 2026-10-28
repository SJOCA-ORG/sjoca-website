# Something about the site that should stay true after the next change.
#
# Not every verification deserves to be one. The test is: would a future change
# that breaks this be a BUG, or a different CHOICE?
#
#   "the home page shows the service times"        -> a bug. Keep.
#   "the heading reads exactly Financially Support" -> rewording is legitimate. Do not keep.
#
# Immutable, deliberately. Changing a promise means creating a new one and
# swapping the id in the revision's list, so the history survives.
class Promise < ApplicationRecord
  include BelongsToOrganization
  has_many :revision_promises, dependent: :destroy
  has_many :revisions, through: :revision_promises

  validates :summary, presence: true, length: { maximum: 120 }
  validates :intent,  presence: true
  validates :script,  presence: true

  # Frozen once written. The whole scheme depends on an id always meaning the
  # same assertion.
  before_update { raise ActiveRecord::ReadOnlyRecord, "promises are immutable; make a new one" }

  def everywhere? = page_slug.blank?
  def scope_text  = everywhere? ? "every page" : "/#{page_slug}"

  def age_text
    return nil if created_at.blank?

    "promised since #{created_at.strftime('%B %Y')}"
  end
end
