class PhotoTag < ApplicationRecord
  belongs_to :photo
  belongs_to :tag

  validates :photo_id, uniqueness: { scope: :tag_id }
end
