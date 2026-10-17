# Removes the widget scaffolding from the published revision, and discards any
# open draft, so the site is back to the start of the acceptance test.
#
# What goes:
#
#   block/calendar, block/upcoming, block/recordings, block/lectionary
#     -- four Liquid templates seeded during the Phase 1 ERB port. NO BLOCK IN
#        THE PUBLISHED SITE USES ANY OF THEM, so removing them changes nothing
#        a visitor sees. They were scaffolding the AI inherited and could not
#        have written.
#
#   the CSS those templates were styled against
#     -- .calendar__*, .upcoming__*, .classes__*, .lectionary__*
#
# This is deliberate, not tidying. The four drops behind those templates each
# decided -- in Ruby, invisibly -- what was worth showing. site.upcoming left
# out every regularly scheduled service, and its one-line description said only
# "notable events in the coming week", so a page was built on top of it that was
# missing Vespers and the Divine Liturgy and nobody could find out why.
#
# They are replaced by one primitive: the server fetches an address, caches it,
# and hands the page JSON. See DataDrop and Site::OutboundFetch.
#
#   bin/rails runner script/clear_widget_scaffolding.rb

WIDGETS = %w[block/calendar block/upcoming block/recordings block/lectionary].freeze
CSS_START = "/* ---------- parish calendar"
CSS_END   = "/* ---------- lists and quotations"

live = Revision.live or abort "no published revision"

in_use = live.blocks.where(kind: WIDGETS.map { |w| w.delete_prefix("block/") }).count
abort "#{in_use} published blocks still use these; not removing them" if in_use.positive?

removed = live.templates.where(name: WIDGETS).destroy_all
puts "removed #{removed.size} templates from revision #{live.id}: #{removed.map(&:name).join(', ')}"

asset = live.theme_assets.find_by(name: ThemeAsset::KINDS.fetch("css"))
if asset
  lines = asset.content.to_s.lines
  from = lines.index { |l| l.start_with?(CSS_START) }
  to   = lines.index { |l| l.start_with?(CSS_END) }

  if from && to && to > from
    note = <<~NOTE
      /* The calendar, "this coming week", the class recordings and the daily
         lectionary were styled here, against markup from four drops that each
         knew -- in Ruby -- what was worth showing. All of it is gone, along with
         the drops. Those things now come in through one primitive: the server
         fetches an address and hands the page JSON (site.data.<name>.json_tag),
         and the markup, the styling and the decisions about what to show are
         written through the admin, where they can be read and changed. */

    NOTE
    asset.update!(content: (lines[0...from] + [note] + lines[to..]).join)
    puts "removed #{to - from} lines of widget CSS (#{asset.content.bytesize} bytes left)"
  else
    puts "widget CSS not found in the stylesheet; left alone"
  end
end

Revision.drafts.each do |draft|
  puts "discarding draft #{draft.id} (#{draft.messages.count} messages) — #{draft.title}"
  draft.update!(state: "discarded")
end

puts
puts "live revision #{live.id}: #{live.summary}"
puts "templates: #{live.templates.count} (#{live.templates.order(:name).pluck(:name).join(', ')})"
puts "drafts open: #{Revision.drafts.count}"
