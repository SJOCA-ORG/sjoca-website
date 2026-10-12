class Block < ApplicationRecord
  # "calendar" renders the parish calendar from our own mirrored data.
  # "embed" remains for genuine third-party iframes.
  KINDS = %w[heading subheading text image embed button calendar upcoming classes].freeze

  belongs_to :section

  validates :kind, inclusion: { in: KINDS }

  def asset = asset_name && LegacyAsset.current(asset_name)
end
