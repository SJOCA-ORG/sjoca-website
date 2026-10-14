class EventDrop < Liquid::Drop
  def initialize(event) = @event = event

  def title      = @event.title
  def notes      = @event.notes.presence
  def time_text  = @event.time_text.presence
  def day        = @event.starts_at.strftime("%A")
  def day_short  = @event.starts_at.strftime("%a")
  def date_num   = @event.starts_at.strftime("%-d")
  def when_text  = @event.when_text
  def elsewhere  = @event.elsewhere
  def cancelled  = @event.cancellation?
  def noteworthy = @event.noteworthy?
  def today      = @event.starts_at.to_date == Date.current
end
