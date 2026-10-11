# Seeds assets the parish owns and we have processed ourselves, as distinct from
# the images scraped off the old Google Sites site.
#
# Each entry becomes a NEW version under its human_name. Because the newest
# published row wins, adding one here changes what a page displays without any
# page, block or template being touched — which is the whole point of the
# legacy_assets design. The superseded row stays, so it is always recoverable.
require "digest"

CURATED_MIME = {
  ".jpeg" => "image/jpeg", ".jpg" => "image/jpeg",
  ".png"  => "image/png",  ".gif" => "image/gif", ".webp" => "image/webp"
}.freeze

root = Pathname.new(ENV.fetch("SJOCA_PHOTO_LIBRARY", File.expand_path("~/sjoca-photo-library")))
spec = Rails.root.join("db/seeds/curated.yml")

unless root.directory?
  warn "!! Photo library not found at #{root}."
  warn "!! Set SJOCA_PHOTO_LIBRARY, or skip — curated assets will not be seeded."
  return
end

created = promoted = skipped = missing = 0

YAML.load_file(spec).each do |entry|
  path = root.join(entry["file"])
  unless path.exist?
    missing += 1
    warn "   missing #{entry['human_name']}: #{path}"
    next
  end

  bytes  = path.binread
  digest = Digest::SHA256.hexdigest(bytes)

  # "Already present" is not the same as "currently showing". Another seed can
  # insert a different version of the same name afterwards and silently win on
  # recency, which is exactly what happened the first time this ran. So compare
  # against the CURRENT version, and re-promote an existing row if it has been
  # overtaken.
  current = LegacyAsset.current(entry["human_name"])
  if current&.sha256 == digest
    skipped += 1
    next
  end

  if (existing = LegacyAsset.find_by(human_name: entry["human_name"], sha256: digest))
    existing.touch(:created_at)
    promoted += 1
    puts "   #{entry['human_name']}: re-promoted to current"
    next
  end

  LegacyAsset.create!(
    human_name:   entry["human_name"],
    data:         bytes,
    content_type: CURATED_MIME.fetch(path.extname.downcase, "image/jpeg"),
    byte_size:    bytes.bytesize,
    sha256:       digest,
    source_url:   "photo-library:#{entry['file']}",
    alt_text:     entry["alt_text"]&.squish,
    status:       "published"
  )
  created += 1
  n = LegacyAsset.versions_of(entry["human_name"]).count
  puts "   #{entry['human_name']}: now #{n} version#{'s' if n != 1}, newest wins"
end

puts "curated assets: #{created} added, #{promoted} re-promoted, #{skipped} already current, #{missing} missing"
