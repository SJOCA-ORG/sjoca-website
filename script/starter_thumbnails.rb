# Photographs of each starter, for the chooser in the operator console.
#
# A look wants looking at. The chooser showed a title and a sentence, which is
# the one thing a person cannot judge a design by.
#
#   bin/rails server                                   # in another terminal
#   bin/rails runner script/starter_thumbnails.rb
#
# For each starter it creates a throwaway organization on its own hostname,
# installs the starter, photographs the home page at a desktop width and a
# phone one, and then deletes the organization again. Nothing is left behind --
# which also means this exercises Organization#destroy and its cascade on every
# run, and that cascade had nothing exercising it before.
#
# The screenshots land in public/starters/ and are committed. They are generic
# by construction: a starter that carried a real organization's content would
# have failed the build long before reaching here.
require "fileutils"
require "open3"
require "net/http"
require "uri"
require "json"
include ActionView::Helpers::NumberHelper

SERVER = ENV.fetch("SERVER", "http://localhost:3000")
PORT   = URI.parse(SERVER).port
OUT    = Rails.root.join("public/starters")
SHOTS  = Rails.root.join("tmp/starter-shots")

abort "Run this with bin/rails runner, not ruby." unless defined?(Rails)
abort "This writes to the development database. Refusing to run in #{Rails.env}." unless Rails.env.development?

begin
  Net::HTTP.get_response(URI(SERVER))
rescue StandardError => e
  abort "No server at #{SERVER} (#{e.class}). Start one with bin/rails server."
end

FileUtils.mkdir_p(OUT)
FileUtils.mkdir_p(SHOTS)

# Shrunk hard on purpose: a chooser wants the SHAPE of a look, not its small
# print, and six full-page screenshots in a public repository is a few megabytes
# of nothing anybody will read.
def shrink(from, to, size)
  system("magick", from.to_s, "-resize", size, "-gravity", "north",
         "-crop", size.sub(/x\d+/, "x#{size.split('x').last}") + "+0+0", "+repage",
         "-strip", "-quality", "82", to.to_s, exception: true)
end

Starter.all.each do |starter|
  # ONE label of subdomain. Rails' development host allowlist contains
  # ".localhost", which matches foo.localhost and does NOT match
  # a.b.localhost -- the first attempt used <name>.starter.localhost and
  # every page came back 403 Blocked hosts.
  host = "#{starter.name}-starter.localhost"
  puts "\n#{starter.title} -> #{host}"

  organization = Organization.create!(name: "#{starter.title} Example",
                                      slug: "starter-example-#{starter.name}",
                                      canonical_url: SERVER)
  organization.add_host(host)

  Organization.acting_as(organization) do
    revision = Revision.create!(state: "published", title: "Starter preview")
    starter.install!(revision)
    revision.site_settings.find_or_initialize_by(key: "name").update!(value: "#{starter.title} Example")
  end

  url = "http://#{host}:#{PORT}/"
  out, err, status = Open3.capture3(
    { "SHOT_DIR" => SHOTS.to_s, "CHROME" => ENV["CHROME"].to_s },
    "node", Rails.root.join("script/visual_check.mjs").to_s, url, "--shots"
  )
  warn err.lines.last.to_s.strip if err.present?

  # visual_check prints {url, widths: {phone: {screenshot: ...}, desktop: {...}}}.
  # The first version of this read a "shots" key that does not exist, found
  # nothing, and said nothing -- it reported six starters done and wrote no
  # files. A rescue nil around a JSON.parse is how a script lies to you.
  unless status.success?
    warn "  visual_check failed for #{starter.name}: #{out.lines.first}"
    next
  end

  widths = JSON.parse(out).fetch("widths", {})
  raise "no screenshots for #{starter.name}: #{out[0, 200]}" if widths.empty?

  widths.each do |width, result|
    path = result["screenshot"]
    raise "#{starter.name} #{width}: no screenshot in the output" if path.blank?
    raise "#{starter.name} #{width}: #{path} is missing" unless File.exist?(path)

    out_file = OUT.join("#{starter.name}-#{width}.png")
    shrink(path, out_file, width == "phone" ? "280x460" : "720x470")
    puts "  #{width.ljust(8)} #{number_to_human_size(File.size(out_file))}  public/starters/#{out_file.basename}"
  end
ensure
  # Deleting the organization takes its revision, pages, sections and blocks
  # with it. If this line stops working, the chooser is the least of it.
  organization&.destroy!
end

puts "\nOrganizations left behind: #{Organization.where("slug LIKE 'starter-example-%'").count} (should be 0)"
