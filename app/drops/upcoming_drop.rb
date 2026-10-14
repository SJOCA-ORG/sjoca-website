# What is different about the coming week: one-off events and anything
# cancelled. The regular round is left out -- nobody needs telling that Vespers
# is on Saturday again.
class UpcomingDrop < Liquid::Drop
  def initialize(days: 7) = @days = days

  def events = CalendarEvent.noteworthy_within(@days).map { |e| EventDrop.new(e) }
  def any    = CalendarEvent.noteworthy_within(@days).any?
end
