# Twenty-six photographs in this table carried EXIF, and eight of those carried
# GPS coordinates -- including the clergy portraits on the leadership page,
# which the deployed site has been serving to anyone who downloads them.
#
# Found while building photo upload: the new intake strips metadata on arrival,
# which raised the question of what was already here.
#
# These particular ones were taken at services, so the coordinates are the
# church's own address, which is on the contact page anyway. That is luck
# rather than design. The same library holds picnics and gatherings in people's
# homes, and nobody would ever DECIDE to publish a parishioner's coordinates --
# it would simply happen, one upload at a time.
#
# Stripping is done IN PLACE, not as a new version. It is the same photograph:
# a new version would orphan nothing but would say, falsely, that someone had
# replaced the picture.
class StripMetadataFromStoredPhotos < ActiveRecord::Migration[8.1]
  def up
    return unless defined?(Admin::ImageTools)

    cleaned = 0
    Photo.find_each do |photo|
      format = photo.content_type.to_s.split("/").last.sub("jpeg", "jpg")
      next unless %w[jpg png webp gif].include?(format)

      stripped = begin
        Admin::ImageTools.strip(photo.data, format)
      rescue StandardError => e
        say "#{photo.human_name} v#{photo.version}: could not be stripped (#{e.class})", true
        next
      end

      next if stripped.bytesize == photo.byte_size && stripped == photo.data

      photo.update_columns(data: stripped, byte_size: stripped.bytesize,
                           sha256: Digest::SHA256.hexdigest(stripped),
                           updated_at: Time.current)
      cleaned += 1
    end
    say "stripped metadata from #{cleaned} photographs", true
  end

  def down
    # The metadata is gone. That is the point.
  end
end
