# One Liquid template. Named like a path ("block/heading") but stored as a row.
class Template < ApplicationRecord
  belongs_to :revision

  validates :name, presence: true, uniqueness: { scope: :revision_id }

  def self.source_for(revision, name)
    where(revision: revision, name: name).pick(:source)
  end
end
