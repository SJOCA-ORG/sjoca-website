# Everything a template can reach that is not the page itself.
#
# Gathered under one object deliberately: {% render %} isolates scope, so each
# nested template must be handed what it needs explicitly. Passing one `site`
# keeps that to a single argument instead of five.
class SiteDrop < BaseDrop
  # Today these are constants; the `settings` table cms-capabilities.md calls
  # for would back them later without any template changing.
  def name    = "Saint John the Baptist Orthodox Church"
  def address = "855 S. Goodman St. Rochester, NY 14620"
  def email   = "fr.david@sjoca.org"

  # Where this site lives, with no trailing slash. Needed wherever a link has
  # nothing to be relative TO: an email has no page, so "/media/home-hero" in
  # it resolves against the mail client and shows a broken picture.
  def url = ENV.fetch("SITE_URL", "http://localhost:3000").sub(%r{/+\z}, "")

  # Outside data, by whatever name it was given. One primitive instead of a drop
  # per feed: see DataDrop.
  def data = @data ||= DataDrop.new(Current.revision)

end
