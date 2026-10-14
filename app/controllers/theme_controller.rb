# Serves the stylesheet and scripts for whichever revision is being rendered.
#
# A route rather than an inline <style>: 26KB on every page response would be
# wasteful, and this way the browser caches it. The URL carries a digest of the
# content, so a published change busts the cache immediately while an unchanged
# one is never re-fetched.
class ThemeController < ApplicationController
  include RevisionScoped

  # Rails refuses a JavaScript response to a non-XHR request
  # (InvalidCrossOriginRequest). That guard exists so a <script> tag on another
  # site cannot read data meant for a signed-in user. This is the opposite case:
  # a public, static, identical-for-everyone asset that a <script> tag is
  # SUPPOSED to load, carrying no user data of any kind.
  skip_forgery_protection

  def stylesheet = serve("css", "text/css")
  def javascript = serve("js",  "text/javascript")

  private

  def serve(kind, type)
    body = ThemeAsset.content_for(Current.revision, kind)
    return head :not_found if body.blank?

    # stale? issues the 304 itself. Do not also call head :not_modified -- that
    # renders twice and 500s every conditional request. See PhotosController.
    return unless stale?(etag: Digest::SHA256.hexdigest(body), public: true)

    expires_in 1.year, public: true
    render plain: body, content_type: type
  end
end
