# A day's scripture readings, mirrored from oca.org.
#
# Mirrored rather than linked so the readings can appear in our own typography,
# feed the weekly bulletin, and keep working when oca.org does not.
class LectionaryDay < ApplicationRecord
  self.table_name = "lectionary_days"

  has_many :readings, -> { order(:position) },
           class_name: "LectionaryReading", dependent: :destroy,
           foreign_key: :lectionary_day_id, inverse_of: :lectionary_day

  validates :on, presence: true, uniqueness: true

  scope :upcoming, -> { where(on: Date.current..).order(:on) }
  scope :for_week, ->(start = Date.current) { where(on: start..(start + 6)).order(:on) }

  def self.today = find_by(on: Date.current)

  # Some days carry more than two readings; the last two are the ones appointed
  # in the lectionary for that day, and earlier entries belong to a
  # commemoration. The parish's rule, not something the markup states.
  def appointed = readings.last(2)

  def epistle = appointed.find { |r| r.kind.to_s.match?(/epistle/i) }
  def gospel  = appointed.find { |r| r.kind.to_s.match?(/gospel/i) }

  def date_text = on.strftime("%A, %-d %B %Y")
end
