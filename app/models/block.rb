class Block < ApplicationRecord
  # "calendar" renders the parish calendar from our own mirrored data.
  # "embed" remains for genuine third-party iframes.
  # The kinds the site ships with. NOT a closed list: a kind is usable as soon
  # as a template named block/<kind> exists in the revision, so adding one is
  # writing a template rather than changing Ruby and deploying.
  KINDS = %w[heading subheading text image embed button calendar upcoming classes lectionary list quote].freeze

  NAME = /\A[a-z][a-z0-9_-]{1,40}\z/

  belongs_to :section
  belongs_to :revision

  validate :kind_has_a_template

  def asset = asset_name && Photo.current(asset_name)

  def self.kinds_in(revision)
    (KINDS + revision.templates.where("name LIKE 'block/%'")
                     .pluck(:name).map { |n| n.delete_prefix("block/") }).uniq.sort
  end

  private

  # Validity follows the templates, not a constant. A kind with no template
  # would render as nothing at all -- content silently disappearing, which on a
  # parish site is the failure that matters.
  def kind_has_a_template
    return errors.add(:kind, "is not a usable name") unless NAME.match?(kind.to_s)
    return if revision.nil?
    return if revision.templates.exists?(name: "block/#{kind}")

    errors.add(:kind, "has no template. Create block/#{kind} first, or use one of: " \
                      "#{Block.kinds_in(revision).join(', ')}")
  end
end
