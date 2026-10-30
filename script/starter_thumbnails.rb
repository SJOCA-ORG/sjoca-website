# Photographs of each starter, for the chooser in the operator console.
#
# A look wants looking at. The chooser showed a title and a sentence, which is
# the one thing a person cannot judge a design by.
#
#   bin/rails server                                   # in another terminal
#   bin/rails runner script/starter_thumbnails.rb
#
# Photographs each sample site where it lives, at a desktop width and a phone
# one. They are organizations serving on their own hostnames, so there is
# nothing to create and nothing to clean up.
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

# The sample sites are organizations now, each already serving on its own
# hostname. So this photographs them where they live, rather than creating a
# throwaway organization per starter, installing a manifest into it and
# deleting it again -- about sixty lines that existed only because a starter
# used to be a folder of YAML with nowhere to be looked at.
Organization.starters.order(:slug).each do |organization|
  short = Starters.short_name(organization)
  host  = organization.hosts.first or next warn("  #{short} has no hostname; skipped")
  url   = "http://#{host}:#{PORT}/"
  puts "\n#{organization.name} -> #{url}"

  out, err, status = Open3.capture3(
    { "SHOT_DIR" => SHOTS.join(short).to_s, "CHROME" => ENV["CHROME"].to_s },
    "node", Rails.root.join("script/visual_check.mjs").to_s, url, "--shots"
  )
  warn err.lines.last.to_s.strip if err.present?

  unless status.success?
    warn "  visual_check failed for #{short}: #{out.lines.first}"
    next
  end

  widths = JSON.parse(out).fetch("widths", {})
  raise "no screenshots for #{short}: #{out[0, 200]}" if widths.empty?

  widths.each do |width, result|
    path = result["screenshot"]
    raise "#{short} #{width}: no screenshot in the output" if path.blank?
    raise "#{short} #{width}: #{path} is missing" unless File.exist?(path)

    out_file = OUT.join("#{short}-#{width}.png")
    shrink(path, out_file, width == "phone" ? "280x460" : "720x470")
    puts "  #{width.ljust(8)} #{number_to_human_size(File.size(out_file))}  public/starters/#{out_file.basename}"
  end
end

puts "\n#{Organization.starters.count} starters photographed."
