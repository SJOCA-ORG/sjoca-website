# CSS (and later JS) the parish can change without a deploy. Appended after the
# compiled stylesheet so it overrides rather than replaces -- a bad rule can
# always be undone by publishing the previous revision.
class ThemeAsset < ApplicationRecord
  belongs_to :revision

  validates :name, presence: true, uniqueness: { scope: :revision_id }

  def self.css_for(revision) = where(revision: revision).order(:name).pluck(:content).join("\n")
end
