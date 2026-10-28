# One hostname that resolves to one organization.
#
# A table rather than a column on organizations, because every organization has
# several from the day it starts -- the apex, www, and whatever the hosting
# platform calls it -- and because a hostname may belong to exactly one
# organization. That last part is a unique index, not a convention: two
# organizations both claiming sjoca.org is not a disagreement to resolve at
# request time.
class OrganizationHost < ApplicationRecord
  belongs_to :organization

  # Lower case, no scheme, no path, no port. What request.host hands us.
  HOST = /\A[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?\z/

  normalizes :host, with: ->(h) { h.to_s.strip.downcase.sub(%r{\Ahttps?://}, "").sub(%r{[:/].*\z}, "") }

  validates :host, presence: true, format: { with: HOST,
    message: "is a hostname on its own — no https://, no port, no path"
  }, uniqueness: { message: "already belongs to an organization" }

  def to_s = host
end
