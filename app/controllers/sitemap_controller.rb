# The sitemap, generated from whatever is published right now.
#
# Not a file anybody maintains: a file nobody maintains goes stale, and a
# sitemap listing pages that no longer exist is worse than none at all. This is
# the live revision, read at request time, which means it is correct the moment
# a revision is published and needs no step in the publish to keep it so.
class SitemapController < ApplicationController
  def show
    revision = Revision.live
    @pages = revision ? Page.in_revision(revision).on_website.ordinary.order(:position, :id) : []
    # Every page that is not an ordinary one -- bulletins now, a newsletter
    # later -- rather than only the kind Ruby happens to know the name of.
    @bulletins = revision ? Page.in_revision(revision).on_website.special.limit(52) : []

    expires_in 1.hour, public: true
    render formats: :xml
  end

  def robots
    expires_in 1.day, public: true
    render plain: <<~TEXT, content_type: "text/plain"
      # Everything here is public and meant to be found.
      User-agent: *
      Allow: /

      # Drafts are served at signed addresses and carry noindex, but say so
      # here as well: a link pasted into a chat is enough to get one crawled.
      Disallow: /*?preview=

      Sitemap: #{SiteDrop.new.url}/sitemap.xml
    TEXT
  end
end
