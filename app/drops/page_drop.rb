class PageDrop < Liquid::Drop
  def initialize(page) = @page = page

  def slug       = @page.slug
  def title      = @page.title
  def nav_title  = @page.nav_title
  def path       = @page.path
  def sections   = @page.sections.map { |s| SectionDrop.new(s) }

  def hero_heading    = presence(Sanitize.inline(@page.hero_heading))
  def hero_subheading = presence(Sanitize.inline(@page.hero_subheading))
  def hero_detail     = @page.hero_detail
  def hero_tall       = @page.tall_hero?

  def hero_photo
    asset = @page.hero_asset
    asset && PhotoDrop.new(asset)
  end

  # Liquid treats "" as truthy, so blank must become nil or every optional
  # field renders an empty tag.
  def presence(v) = v.presence

  def has_hero = @page.hero_heading.present? || @page.hero_asset.present?
end
