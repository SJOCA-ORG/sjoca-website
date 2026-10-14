# One top-level navigation entry and its submenu.
class NavDrop < Liquid::Drop
  def initialize(page, current_slug) = (@page = page; @current = current_slug)

  def title    = @page.nav_title
  def path     = @page.path
  def slug     = @page.slug
  def current  = @page.slug == @current
  def children = @page.children.map { |k| NavDrop.new(k, @current) }
  def has_children = @page.children.any?

  # A parent with its own content lists itself first, so the submenu does not
  # imply the parent is only a heading.
  def self_title = @page.self_nav_title
end
