# What is different about the coming week: one-off events and anything
# cancelled. The regular round is left out -- nobody needs telling that Vespers
# is on Saturday again.
#
# How far ahead to look belongs to the template:
#   {% for event in site.upcoming.events limit: 5 %}
class UpcomingDrop < Liquid::Drop
  CAP_DAYS = 60

  def events = @events ||= CalendarEvent.noteworthy_within(CAP_DAYS).map { |e| EventDrop.new(e) }
  def any    = events.any?
  def count  = events.size

  # The next week only, which is what the home page wants.
  def this_week = CalendarEvent.noteworthy_within(7).map { |e| EventDrop.new(e) }
end
