# The parish calendar, from our own mirror of ChurchTrac.
#
# `weeks` groups events so the shape of the liturgical week is visible at a
# glance rather than a flat list in which Vespers appears fifty times. Grouping
# is genuinely awkward in Liquid, so it is done here -- but HOW MANY weeks to
# show belongs to the template:
#
#   {% for week in site.calendar.weeks limit: 8 %}
#
# `events` is the same data ungrouped, for a template that wants its own shape.
class CalendarDrop < Liquid::Drop
  CAP_DAYS = 365

  def weeks
    @weeks ||= CalendarEvent.within(CAP_DAYS)
                            .group_by { |e| e.starts_at.to_date.beginning_of_week(:sunday) }
                            .sort
                            .map { |start, events| WeekDrop.new(start, events) }
  end

  def events = @events ||= CalendarEvent.within(CAP_DAYS).sort_by(&:starts_at).map { |e| EventDrop.new(e) }
  def any    = events.any?
  def count  = events.size

  class WeekDrop < Liquid::Drop
    def initialize(start, events) = (@start = start; @events = events)

    def heading
      @start == Date.current.beginning_of_week(:sunday) ? "This week" : "Week of #{@start.strftime('%-d %B')}"
    end

    def events = @events.sort_by(&:starts_at).map { |e| EventDrop.new(e) }
    def count  = @events.size
  end
end
