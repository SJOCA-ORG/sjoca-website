# One occurrence of a parish event, mirrored from ChurchTrac.
#
# ChurchTrac stays the place events are created and edited — nobody types a
# service into this app. We keep a local copy so the site can render services in
# its own style, show the next service anywhere, survive ChurchTrac being slow
# or down, and publish an iCal feed.
class CalendarEvent < ApplicationRecord
  SOURCES = %w[churchtrac local].freeze

  # The services spelled out in the published schedule, and nothing else.
  #
  # A visitor arrives wanting to know when the services are; that is what the
  # Service Times block answers. Anything else — a class, a meeting, a
  # collection — is secondary to them and therefore worth announcing, even when
  # it happens every week. So the Wednesday adult education class belongs in
  # upcoming events despite being as regular as the Akathist before it.
  #
  # This list must stay in step with the Service Times block on the home page.
  # Two copies of the same fact: the duplication the Settings resource is meant
  # to end (see docs/cms-capabilities.md).
  SERVICE_TITLES = [
    /\A(great\s+)?vespers\z/i,
    /\Adivine\s+liturgy\z/i,
    /\Aakathist\z/i,
    # Compline was the Wednesday service until Fr David replaced it with the
    # Akathist. Kept so older entries still classify correctly.
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

  # Everything on that is not one of the published services.
  def self.noteworthy_within(days) = within(days).select(&:noteworthy?)

  # One of the published services, in its usual weekly slot. The recurring
  # check matters: an extra Vespers added for a feast is not the ordinary
  # Saturday one, and a visitor would want to hear about it.
  def scheduled_service? = recurring? && SERVICE_TITLES.any? { |p| p.match?(title.to_s.strip) }
  def cancellation? = CANCELLATION.match?(title.to_s.strip)
  def noteworthy? = cancellation? || !scheduled_service?

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
