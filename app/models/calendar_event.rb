# One occurrence of a parish event, mirrored from ChurchTrac.
#
# ChurchTrac stays the place events are created and edited — nobody types a
# service into this app. We keep a local copy so the site can render services in
# its own style, show the next service anywhere, survive ChurchTrac being slow
# or down, and publish an iCal feed.
class CalendarEvent < ApplicationRecord
  SOURCES = %w[churchtrac local].freeze

  # The weekly round. Everything else is worth drawing attention to, which is
  # what the home page and the calendar's "what's different" section rely on:
  # a parish does not need telling that Vespers is on Saturday again.
  REGULAR_TITLES = [
    /\A(great\s+)?vespers\z/i,
    /\Adivine\s+liturgy\z/i,
    /\Aakathist\z/i,
    /\Acompline\z/i,
    /\A(reading\s+of\s+the\s+)?hours\z/i
  ].freeze

  # Parishes announce a cancellation by adding an event that says so, since
  # deleting one leaves no trace for anybody already expecting it.
  CANCELLATION = /\A(no|cancell?ed|canceled)\b|\bcancell?ed\b/i

  validates :title, :starts_at, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :churchtrac_id, uniqueness: { scope: :starts_at }, allow_nil: true

  scope :from_churchtrac, -> { where(source: "churchtrac") }
  scope :local,           -> { where(source: "local") }

  scope :upcoming, -> { where(starts_at: Time.current.beginning_of_day..).order(:starts_at) }
  scope :between,  ->(from, to) { where(starts_at: from..to).order(:starts_at) }
  scope :on_day,   ->(date) { between(date.beginning_of_day, date.end_of_day) }
  scope :within,   ->(days) { between(Time.current.beginning_of_day, days.days.from_now.end_of_day) }

  def self.next_services(limit = 3) = upcoming.limit(limit)

  # Anything the parish would not already assume: a one-off, or a cancellation
  # of something they would.
  def self.noteworthy_within(days) = within(days).select(&:noteworthy?)

  def regular?     = REGULAR_TITLES.any? { |p| p.match?(title.to_s.strip) }
  def cancellation? = CANCELLATION.match?(title.to_s.strip)
  def noteworthy?  = cancellation? || !regular?

  def all_day_or_timeless? = all_day? || starts_at.strftime("%H:%M") == "00:00"

  def time_text
    return nil if all_day_or_timeless?

    starts_at.strftime("%-l:%M%P").sub(":00", "")
  end

  def day_text  = starts_at.strftime("%A")
  def date_text = starts_at.strftime("%-d %B")

  def when_text = [day_text, date_text, time_text].compact.join(", ")

  def at_church? = location.to_s.include?("Goodman")

  # Somewhere to show, when it is not the parish's own building.
  def elsewhere = at_church? ? nil : location.presence
end
