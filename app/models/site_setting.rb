# A named value the parish sets: its name, its address, who to write to.
#
# These were constants in Ruby. That meant the parish could not correct its own
# address without a developer, and -- worse for a second parish -- the code
# asserted which parish it was.
#
# Ruby still knows that a site HAS a name and an address. It does not know what
# they are. That is the line: generic shape here, particular facts in the
# revision, where they can be read and changed by asking.
class SiteSetting < ApplicationRecord
  belongs_to :revision

  validates :key, presence: true, format: {
    with: /\A[a-z][a-z0-9_]{0,40}\z/,
    message: "is lower case letters, numbers and underscores"
  }, uniqueness: { scope: :revision_id }

  def self.for(revision) = where(revision: revision).pluck(:key, :value).to_h
end
