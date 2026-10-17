class Page < ApplicationRecord
  belongs_to :revision
  has_many :sections, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :page

  validates :slug, :title, :nav_title, presence: true
  # Unique *within a revision*. A slug necessarily repeats across revisions --
  # that is what a revision is.
  validates :slug, uniqueness: { scope: :revision_id }

  scope :in_revision, ->(rev) { where(revision: rev) }
  # :id is the tiebreak, not decoration. Two pages shared position 5 and the
  # menu order between them was undefined -- the same class of bug that had
  # one photograph on the deployed site and another locally.
  scope :in_nav,      -> { where(show_in_nav: true).order(:position, :id) }
  scope :top_level,   -> { where(parent_slug: nil) }

  def self.find_by_path!(path, revision: Current.revision)
    in_revision(revision).find_by!(slug: path.to_s.sub(%r{\A/}, ""))
  end

  # Scoped to this page's own revision, or a preview would show the live
  # site's children underneath a draft parent.
  def children = self.class.in_revision(revision_id).where(parent_slug: slug).in_nav

  def hero_asset = Photo.find_version(hero_asset_name, hero_asset_version)
  def tall_hero? = hero_size == "tall"
  def path = "/#{slug}"
end
