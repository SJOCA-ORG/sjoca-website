# Reduce every stored photograph to web size, in place.
#
# Run script/export_photo_originals.rb FIRST. This is irreversible from the
# database's point of view: the full-resolution bytes are replaced, and for
# anything uploaded through the editor the database was their only copy.
#
# In place rather than as a new version, deliberately. This is not a different
# picture, so a page pointing at "leadership-fr-david version 2" should go on
# meaning the same photograph -- just one that no longer carries ten times the
# pixels any screen will use.
require "digest"

DRY = ENV["DRY_RUN"] == "true"
before = Photo.sum(:byte_size)
changed = 0
saved = 0
failed = []

Photo.order(:id).find_each do |photo|
  info = Admin::ImageTools.identify(photo.data)
  next if info.blank?
  next if [info[:width], info[:height]].max <= Admin::ImageTools::MAX_SIDE

  format = case photo.content_type
           when "image/png" then "png"
           when "image/webp" then "webp"
           when "image/gif" then "gif"
           else "jpg"
           end

  begin
    smaller = Admin::ImageTools.strip(photo.data, format)
  rescue StandardError => e
    failed << "#{photo.human_name} v#{photo.version}: #{e.message}"
    next
  end

  # Only if it genuinely helps. A picture that grows is left alone.
  next unless smaller.bytesize < photo.byte_size

  saved += photo.byte_size - smaller.bytesize
  changed += 1

  unless DRY
    photo.update_columns(data: smaller, byte_size: smaller.bytesize,
                         sha256: Digest::SHA256.hexdigest(smaller),
                         updated_at: Time.current)
  end
end

after = Photo.sum(:byte_size)
puts "#{DRY ? '(dry run) ' : ''}#{changed} of #{Photo.count} photographs reduced"
puts "stored bytes: #{(before / 1024.0 / 1024).round} MB -> #{(after / 1024.0 / 1024).round} MB" unless DRY
puts "would save: #{(saved / 1024.0 / 1024).round} MB" if DRY
failed.each { |f| puts "  FAILED #{f}" }
