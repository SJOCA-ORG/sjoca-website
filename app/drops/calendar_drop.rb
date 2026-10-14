# The parish calendar, grouped by week so the shape of the liturgical week is
# visible at a glance rather than a flat list in which Vespers appears fifty
# times.
class CalendarDrop < Liquid::Drop
  def initialize(days: 56) = @days = days

  def weeks
    CalendarEvent.within(@days)
                 .group_by { |e| e.starts_at.to_date.beginning_of_week(:sunday) }
                 .sort
                 .map { |start, events| WeekDrop.new(start, events) }
  end

  def any = CalendarEvent.within(@days).exists?

  class WeekDrop < Liquid::Drop
    def initialize(start, events) = (@start = start; @events = events)

    def heading
      @start == Date.current.beginning_of_week(:sunday) ? "This week" : "Week of #{@start.strftime('%-d %B')}"
    end

    def events = @events.sort_by(&:starts_at).map { |e| EventDrop.new(e) }
  end
end
