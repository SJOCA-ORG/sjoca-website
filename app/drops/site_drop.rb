# Everything a template can reach that is not the page itself.
#
# Gathered under one object deliberately: {% render %} isolates scope, so each
# nested template must be handed what it needs explicitly. Passing one `site`
# keeps that to a single argument instead of five.
class SiteDrop < BaseDrop
  # The revision being RENDERED, not whatever is globally current.
  #
  # Reading Current.revision here was wrong in a way that only showed up under
  # a full test run: a preview renders one revision while another is current,
  # and the page would then carry the other revision's name and address. The
  # renderer knows which revision it is rendering; it says so.
  def initialize(revision = nil)
    @revision = revision || Current.revision
    super()
  end
  # Set by the parish, in its revision, not written into Ruby.
  #
  # The fallbacks are what these were as constants, so a revision made before
  # the settings table existed still renders. Ruby knows a site HAS a name and
  # an address; it does not know what they are, which is what lets a second
  # parish run the same code.
  # Deliberately NOT this parish's details.
  #
  # They were, for an hour, and that is a trap: a second parish installing this
  # with no settings yet would have published "Saint John the Baptist Orthodox
  # Church" and a Rochester address on its own website. A site that has not been
  # told its name should look unconfigured, not like somebody else.
  #
  # Every revision that is not discarded already carries real settings, so this
  # is reached only by a brand new installation.
  FALLBACK = { "name" => "This site" }.freeze

  def name    = setting("name")
  def address = setting("address")
  def email   = setting("email")

  # Anything else the parish has named, reachable as {{ site.settings.x }}.
  def settings = @settings ||= SiteSetting.for(@revision)

  def setting(key)
    settings[key].presence || FALLBACK[key]
  rescue StandardError
    FALLBACK[key]
  end

  # Where this site lives, with no trailing slash. Needed wherever a link has
  # nothing to be relative TO: an email has no page, so "/media/home-hero" in
  # it resolves against the mail client and shows a broken picture.
  def url = Organization.current_url

  # Outside data, by whatever name it was given. One primitive instead of a drop
  # per feed: see DataDrop.
  def data = @data ||= DataDrop.new(@revision)

end
