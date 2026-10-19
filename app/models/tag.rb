# A label on a photograph, chosen from a menu.
#
# Two names on purpose. `label` is what somebody typed -- "Feast Days", "Fr
# David" -- and is what the menu shows. `name` is that reduced to one canonical
# form, which is what makes "feast days", "Feast Days" and "feast-days" the same
# tag instead of three.
class Tag < ApplicationRecord
  has_many :photo_tags, dependent: :destroy
  has_many :photos, through: :photo_tags

  validates :label, presence: true
  validates :name, presence: true, uniqueness: true

  before_validation :canonicalise

  scope :in_menu, -> { order(:label) }

  def self.canonical(text) = text.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")

  # Find the tag somebody means, or make it. Typing a new tag IS how a new tag
  # is created -- asking a volunteer to go and define one first, somewhere else,
  # is how tagging stops happening.
  def self.for(text)
    canonical_name = canonical(text)
    return nil if canonical_name.blank?

    find_by(name: canonical_name) || create!(name: canonical_name, label: text.to_s.strip)
  end

  def count_of_photos = photos.count

  private

  def canonicalise
    self.label = label.to_s.strip
    self.name = self.class.canonical(name.presence || label)
  end
end
