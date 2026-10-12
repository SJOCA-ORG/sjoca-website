module YouTube
  # Mirrors the adult education playlist into class_recordings.
  #
  # Same posture as the ChurchTrac importer: a failed read changes nothing, and
  # an empty result is refused rather than applied. The source here is a scrape
  # rather than an API, so that caution matters more, not less — YouTube's
  # markup will change one day, and the failure mode must be a stale list rather
  # than an empty page.
  class RecordingImporter
    Result = Struct.new(:status, :fetched, :created, :updated, :removed, :message,
                        keyword_init: true)

    def initialize(playlist_id: Rails.application.config.adult_education.playlist_id,
                   feed: nil)
      @feed = feed || PlaylistFeed.new(playlist_id)
    end

    def call
      videos = feed.videos
      return refused(videos.size) if videos.empty?

      created = updated = 0
      now = Time.current

      ClassRecording.transaction do
        videos.each do |attrs|
          record = ClassRecording.find_or_initialize_by(youtube_id: attrs[:youtube_id])
          was_new = record.new_record?
          record.assign_attributes(attrs.merge(synced_at: now))
          changed = (record.changed - %w[synced_at updated_at]).any?
          record.save!
          if was_new then created += 1
          elsif changed then updated += 1
          end
        end

        # Removed from the playlist upstream means removed here.
        removed = ClassRecording.where("synced_at < ?", now).delete_all
        Result.new(status: "ok", fetched: videos.size, created: created,
                   updated: updated, removed: removed, message: nil)
      end
    rescue PlaylistFeed::FeedError, SocketError, Timeout::Error => e
      Result.new(status: "failed", fetched: 0, created: 0, updated: 0, removed: 0,
                 message: e.message)
    end

    private

    attr_reader :feed

    def refused(count)
      Result.new(status: "refused", fetched: count, created: 0, updated: 0, removed: 0,
                 message: "Playlist came back empty; refusing to clear the recordings")
    end
  end
end
