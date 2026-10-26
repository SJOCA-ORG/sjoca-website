# Write every photograph in the database out to the photo library, full size.
#
# The database is the only copy of anything uploaded through the editor. Before
# the stored copies are reduced to web size, the originals belong somewhere that
# is backed up and is not this application -- the shared library folder, which
# lives on Google Drive.
#
# Safe to run more than once: a file already written is left alone.
require "digest"
require "fileutils"

lib  = ENV["SJOCA_PHOTO_LIBRARY"].presence || File.join(Dir.home, "sjoca-photo-library")
dest = File.join(lib, "from-database")
FileUtils.mkdir_p(dest)

manifest = File.join(dest, "manifest.csv")
written = skipped = 0
bytes = 0

# Written by hand rather than with the csv library, which is no longer a
# default gem in Ruby 3.4 and is not worth a dependency for eight columns.
quote = ->(v) { %("#{v.to_s.gsub('"', '""')}") }

File.open(manifest, "w") do |csv|
  csv.puts %w[file human_name version content_type byte_size sha256 uploaded_at alt_text].join(",")

  Photo.order(:human_name, :version).find_each do |p|
    ext = case p.content_type
          when "image/png" then "png"
          when "image/webp" then "webp"
          when "image/gif" then "gif"
          else "jpg"
          end
    name = "#{p.human_name}-v#{p.version}.#{ext}"
    path = File.join(dest, name)

    if File.exist?(path) && File.size(path) == p.byte_size
      skipped += 1
    else
      File.binwrite(path, p.data)
      written += 1
      bytes += p.byte_size
    end

    csv.puts [name, p.human_name, p.version, p.content_type, p.byte_size, p.sha256,
              p.uploaded_at, p.alt_text].map(&quote).join(",")
  end
end

puts "wrote #{written}, already there #{skipped}  (#{(bytes / 1024.0 / 1024).round} MB)"
puts "into #{dest}"
puts "manifest: #{manifest}"
