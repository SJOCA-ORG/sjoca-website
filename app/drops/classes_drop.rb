class ClassesDrop < Liquid::Drop
  def initialize(limit: 3) = @limit = limit

  def recordings = ClassRecording.latest(@limit).map { |r| RecordingDrop.new(r) }
  def any          = ClassRecording.latest(@limit).any?
  def playlist_url = Rails.application.config.adult_education.playlist_url

  class RecordingDrop < Liquid::Drop
    def initialize(rec) = @rec = rec

    def title     = @rec.clean_title
    def number    = @rec.number
    def date_text = @rec.date_text
    def watch_url = @rec.watch_url
    def thumbnail = @rec.thumbnail_url
  end
end
