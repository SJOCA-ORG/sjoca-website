# One turn of the editing conversation, persisted so a session survives a
# reload, a logout, or coming back tomorrow.
class RevisionMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :revision

  validates :role, inclusion: { in: ROLES }

  scope :for_model, -> { order(:created_at) }

  # "stopping" is still in flight -- the turn finishes its current step and
  # bows out -- so anything asking "is this running" must count it.
  def working? = state.in?(%w[working stopping])
  def stopping? = state == "stopping"
end
