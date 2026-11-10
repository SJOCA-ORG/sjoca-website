# One turn of the editing conversation, persisted so a session survives a
# reload, a logout, or coming back tomorrow.
class RevisionMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :revision

  validates :role, inclusion: { in: ROLES }

  scope :for_model, -> { order(:created_at) }

  scope :live, -> { where(state: %w[working stopping]) }

  # A turn whose job died never got to mark itself done: a deploy, a restart, or
  # an instance running out of memory takes the process with the job in it.
  #
  # EditingTurnJob holds its semaphore for exactly as long as a turn can take,
  # so anything still "working" or "stopping" after that is not slow, it is
  # abandoned. On 9 November 2026 two were left behind by restarts and the chat
  # page reported the OLDER of them on every poll for fourteen hours -- a banner
  # reading "Stopping..." over a turn that was running perfectly well, repainted
  # two or three times a second.
  scope :stranded, -> { live.where(created_at: ...EditingTurnJob::LOCK_DURATION.ago) }

  # "stopping" is still in flight -- the turn finishes its current step and
  # bows out -- so anything asking "is this running" must count it.
  def working? = state.in?(%w[working stopping])
  def stopping? = state == "stopping"
end
