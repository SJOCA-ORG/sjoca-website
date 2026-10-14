# Everything a template can reach that is not the page itself.
#
# Gathered under one object deliberately: {% render %} isolates scope, so each
# nested template must be handed what it needs explicitly. Passing one `site`
# keeps that to a single argument instead of five.
class SiteDrop < Liquid::Drop
  # Today these are constants; the `settings` table cms-capabilities.md calls
  # for would back them later without any template changing.
  def name    = "Saint John the Baptist Orthodox Church"
  def address = "855 S. Goodman St. Rochester, NY 14620"
  def email   = "fr.david@sjoca.org"

  def calendar   = @calendar   ||= CalendarDrop.new
  def upcoming   = @upcoming   ||= UpcomingDrop.new
  def recordings = @recordings ||= RecordingsDrop.new
  def lectionary = @lectionary ||= LectionaryDrop.new
end
