class Block < ApplicationRecord
  KINDS = %w[heading subheading text image embed button].freeze

  belongs_to :section

  validates :kind, inclusion: { in: KINDS }

  def asset = asset_name && LegacyAsset.current(asset_name)
end
