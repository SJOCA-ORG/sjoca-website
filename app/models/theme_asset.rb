# CSS and JavaScript the parish can change without a deploy. Appended after the
# compiled stylesheet so it overrides rather than replaces -- a bad rule is
# always undone by publishing the previous revision.
class ThemeAsset < ApplicationRecord
  KINDS = { "css" => "overrides.css", "js" => "overrides.js" }.freeze

  belongs_to :revision

  validates :name, presence: true, uniqueness: { scope: :revision_id }

  def self.css_for(revision) = content_for(revision, "css")
  def self.js_for(revision)  = content_for(revision, "js")

  def self.content_for(revision, kind)
    where(revision: revision, name: KINDS.fetch(kind)).pick(:content).to_s
  end
end
