# Adult-education class recordings, mirrored from the parish YouTube playlist.
#
# This exposes DATA, not a presentation decision. How many to show, and in what
# order, belongs to the template:
#
#   {% for rec in site.recordings.all limit: 3 %}
#
# The cap below is a safety bound, not a design choice -- it stops a template
# accidentally rendering every recording ever made.
class RecordingsDrop < BaseDrop
  CAP = 100

  def all   = @all ||= ClassRecording.latest(CAP).map { |r| RecordingDrop.new(r) }
  def any   = all.any?
  def count = all.size

  def playlist_url = Rails.application.config.adult_education.playlist_url

  class RecordingDrop < BaseDrop
    def initialize(rec) = @rec = rec

    def title     = @rec.clean_title
    def number    = @rec.number
    def date_text = @rec.date_text
    def watch_url = @rec.watch_url
    def thumbnail = @rec.thumbnail_url
  end
end
