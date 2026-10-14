# Seeds the photos table from the images captured off the current
# Google Sites site.
#
# Where the bytes come from: reference/current-site/images/, populated by
# reference/current-site/capture.sh. Those files are NOT in git -- parish
# photos do not belong in a public repo -- so this seed must be run from a
# machine that has done a capture.
#
# For the first production seed, run it from a developer machine pointed at the
# production database rather than on the server:
#
#   DATABASE_URL=<production-url> bin/rails db:seed
#
# After that, production holds the only copy. See docs/.
#
# Idempotent: identical bytes under the same human_name are skipped, so
# re-running does not create spurious "new versions".
require "digest"

# Extension -> MIME. Marcel ships with Active Storage, which this app skips
# (asset bytes live in photos, so there is nothing for it to do).
MIME_BY_EXT = {
  ".jpeg" => "image/jpeg", ".jpg" => "image/jpeg",
  ".png"  => "image/png",  ".gif" => "image/gif",
  ".webp" => "image/webp", ".svg" => "image/svg+xml"
}.freeze

assets   = YAML.load_file(Rails.root.join("db/seeds/assets.yml"))
manifest = Rails.root.join("reference/current-site/images/manifest.tsv")

unless manifest.exist?
  warn "!! No captured images at #{manifest}."
  warn "!! Run reference/current-site/capture.sh first, then re-run db:seed."
  warn "!! Skipping photos."
  return
end

# source URL -> local file on disk
by_url = manifest.readlines.filter_map { |line|
  _slug, file, url = line.chomp.split("\t")
  [url, Rails.root.join("reference/current-site", file)] if url
}.to_h

created = skipped = missing = 0

assets.each do |a|
  path = by_url[a["source_url"]]
  if path.nil? || !path.exist?
    missing += 1
    warn "   missing bytes for #{a['human_name']}"
    next
  end

  bytes  = path.binread
  digest = Digest::SHA256.hexdigest(bytes)

  if Photo.exists?(human_name: a["human_name"], sha256: digest)
    skipped += 1
    next
  end

  Photo.create!(
    human_name:   a["human_name"],
    data:         bytes,
    content_type: MIME_BY_EXT.fetch(path.extname.downcase, "image/jpeg"),
    byte_size:    bytes.bytesize,
    sha256:       digest,
    source_url:   a["source_url"],
    alt_text:     a["alt_text"].presence,
    status:       "published"
  )
  created += 1
end

puts "photos: #{created} created, #{skipped} already present, #{missing} missing"
