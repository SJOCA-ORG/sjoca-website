# A recording of an adult education class, mirrored from the parish's YouTube
# playlist so the site can list them without anyone maintaining a list by hand.
class ClassRecording < ApplicationRecord
  validates :youtube_id, :title, presence: true
  validates :youtube_id, uniqueness: true

  # Newest first. Prefer the date in the title, fall back to playlist order.
  scope :newest_first, -> { order(Arel.sql("held_on DESC NULLS LAST, number DESC NULLS LAST, position ASC")) }
  scope :latest, ->(n = 3) { newest_first.limit(n) }

  def watch_url     = "https://www.youtube.com/watch?v=#{youtube_id}"
  def thumbnail_url = "https://i.ytimg.com/vi/#{youtube_id}/hqdefault.jpg"

  # "Catechumen Class" is the parish's own shorthand; strip the numbering and
  # date so the page can present them as its own columns.
  def clean_title
    title.sub(/\A#\s*\d+\s*/, "").sub(/[\s_-]*\d{1,2}[-\/]\d{1,2}[-\/]\d{4}\s*\z/, "").strip.presence || title
  end

  def date_text = held_on&.strftime("%-d %B %Y")
end
