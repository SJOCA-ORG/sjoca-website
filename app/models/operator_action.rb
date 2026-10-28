# One thing an application administrator did.
#
# Append-only by convention and by having no update path: nothing in the app
# writes to an existing row. See the migration for why this table belongs to
# nobody -- an organization that can read or edit the log of who looked at its
# data is reading other customers' business, or rewriting its own history.
class OperatorAction < ApplicationRecord
  ACTIONS = %w[entered created suspended resumed invited].freeze

  belongs_to :user, optional: true
  belongs_to :organization, optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :newest_first, -> { order(created_at: :desc) }

  # Deliberately not `log` or `record`: the sentence reads as what happened.
  def self.note!(action, organization:, user:, detail: nil, ip: nil)
    create!(action: action.to_s, organization: organization, user: user,
            detail: detail, ip: ip, created_at: Time.current)
  end

  def to_s
    who = user&.email || "a deleted account"
    "#{who} #{action} #{organization&.name || 'a deleted organization'}"
  end
end
