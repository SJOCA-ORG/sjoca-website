# The site's CSS and JavaScript, as database rows rather than files, so the
# parish can change how the site looks without a deploy.
#
# `site.css` is the whole stylesheet -- not an override layer. Overriding is easy
# but un-setting is awkward: you write a counter-rule, reach for !important, and
# that is what turns into a mess over a few seasons. Editing the real thing
# avoids the layering. Safety comes from the revision, not from read-only files:
# a bad stylesheet is previewed before publishing and undone by republishing.
class ThemeAsset < ApplicationRecord
  KINDS = { "css" => "site.css", "js" => "site.js" }.freeze

  belongs_to :revision

  validates :name, presence: true, uniqueness: { scope: :revision_id }

  def self.css_for(revision) = content_for(revision, "css")
  def self.js_for(revision)  = content_for(revision, "js")

  def self.content_for(revision, kind)
    where(revision: revision, name: KINDS.fetch(kind)).pick(:content).to_s
  end

  # The URL carries a digest, so a stylesheet can be cached hard and still change
  # the moment a revision is published.
  def self.digest_for(revision, kind)
    Digest::SHA256.hexdigest(content_for(revision, kind))[0, 12]
  end
end
