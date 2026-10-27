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
  # Nothing kept off the website can be in the menu of one.
  scope :in_nav,      -> { where(show_in_nav: true, on_website: true).order(:position, :id) }

  # What a page IS, as opposed to what is on it.
  #
  # A layout NAMES A TEMPLATE in the same revision. "page" is the ordinary site
  # page. "bulletin" is 5.5 x 8.5, dated and printable because a template called
  # "bulletin" says so -- not because Ruby knows the word.
  #
  # This was a closed list of exactly those two until 27 October 2026, which
  # meant a parish wanting a quarterly newsletter needed a developer. It does
  # not: it needs a template called "newsletter", which the AI can write, since
  # templates are rows. Site::PageRenderer was already general and falls back to
  # "page" when a revision has no such template, so nothing here needs to check
  # that a template exists yet -- a page may legitimately be made before its
  # template is.
  ORDINARY = "page".freeze
  LAYOUT_NAME = /\A[a-z][a-z0-9_-]{0,40}\z/

  validates :layout, presence: true, format: {
    with: LAYOUT_NAME,
    message: "names a template, so it must be lower case letters, numbers, - or _"
  }

  # On the website, or made here and kept here.
  #
  # A page that is not on the website still renders, is still previewed, and is
  # still exported as a PDF or an email -- it is simply not served to visitors
  # and not offered to search engines. A bulletin is the obvious case: the
  # parish makes it, prints it and sends it, and nobody needs a stale copy of
  # last March's at a public address.
  scope :on_website,  -> { where(on_website: true) }
  scope :off_website, -> { where(on_website: false) }

  scope :ordinary,     -> { where(layout: ORDINARY) }
  scope :laid_out_as,  ->(name) { where(layout: name).order(dated_on: :desc, id: :desc) }
  # Everything that is not an ordinary page: bulletins today, a newsletter
  # tomorrow, without this needing to be told about it.
  scope :special,      -> { where.not(layout: ORDINARY).order(dated_on: :desc, id: :desc) }
  scope :dated,        -> { where.not(dated_on: nil).order(dated_on: :desc, id: :desc) }

  # Sugar, kept deliberately. Three published pages and four AI tools say
  # "bulletin", and there is no reason to rename them -- the point was to stop
  # the concept being PRIVILEGED, not to pretend it does not exist.
  scope :bulletins, -> { laid_out_as("bulletin") }

  def bulletin? = layout == "bulletin"

  # The day this page is FOR -- a bulletin's Sunday, a newsletter's quarter --
  # which is what its readings and services are computed from, not the day
  # somebody edited it.
  def dated_for = dated_on || created_at&.to_date
  alias bulletin_date dated_for
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
