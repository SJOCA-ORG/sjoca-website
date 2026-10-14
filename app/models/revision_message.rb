# One turn of the editing conversation, persisted so a session survives a
# reload, a logout, or coming back tomorrow.
class RevisionMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :revision

  validates :role, inclusion: { in: ROLES }

  scope :for_model, -> { order(:created_at) }
end
