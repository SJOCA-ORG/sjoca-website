class Page < ApplicationRecord
  has_many :sections, -> { order(:position) }, dependent: :destroy, inverse_of: :page

  validates :slug, :title, :nav_title, presence: true
  validates :slug, uniqueness: true

  scope :in_nav,    -> { where(show_in_nav: true).order(:position) }
  scope :top_level, -> { where(parent_slug: nil) }

  def self.find_by_path!(path) = find_by!(slug: path.to_s.sub(%r{\A/}, ""))

  def children = Page.where(parent_slug: slug).in_nav
  def hero_asset = hero_asset_name && LegacyAsset.current(hero_asset_name)
  def tall_hero? = hero_size == "tall"
  def path = "/#{slug}"
end
