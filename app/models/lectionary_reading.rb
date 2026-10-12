class LectionaryReading < ApplicationRecord
  belongs_to :lectionary_day, class_name: "LectionaryDay"

  validates :citation, :position, presence: true

  def label = [kind.presence, citation].compact.join(" — ")
end
