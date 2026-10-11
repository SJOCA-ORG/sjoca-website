# Invented calendar entries, for demonstrating the site before the parish has
# put the real equivalents into ChurchTrac.
#
# These are source: "local", which exempts them from the importer's pruning —
# otherwise the next sync would delete them as events ChurchTrac no longer
# knows about. That is also how the parish could add site-only entries later.
#
# Guarded: only runs when asked, and never in production.
#
#   DEMO_CALENDAR=1 bin/rails db:seed
#   DEMO_CALENDAR=clear bin/rails db:seed    # remove them again
return if Rails.env.production?

mode = ENV["DEMO_CALENDAR"]
return if mode.blank?

if mode == "clear"
  n = CalendarEvent.local.delete_all
  puts "demo calendar: removed #{n} invented events"
  return
end

# Anchored to the NEXT occurrence of each weekday, not the current week —
# otherwise the demo events land on days already past and nothing shows.
DEMO = [
  # A cancellation — the case the home page most needs to surface, because it
  # contradicts what the parish already expects to be true.
  { title: "No Compline this week — Fr. David away",
    on: Date.current.next_occurring(:wednesday), at: "18:00", duration: 0,
    notes: "Compline resumes next Wednesday." },

  # A one-off that is not part of the weekly round.
  { title: "Parish Council Meeting",
    on: Date.current.next_occurring(:friday), at: "19:00", duration: 90,
    location: "855 South Goodman (St. John's)" },

  # Something off-site, to show location being used.
  { title: "Food Cupboard collection",
    on: Date.current.next_occurring(:saturday), at: "09:30", duration: 120,
    location: "South Wedge Food Program" },

  # The meeting this whole project is working towards.
  { title: "Annual General Meeting",
    on: Date.new(2026, 11, 15), at: "12:00", duration: 120,
    location: "855 South Goodman (St. John's)",
    notes: "Following coffee hour. Presentation of the new parish website." }
].freeze

created = 0
DEMO.each do |e|
  starts_at = Time.zone.parse("#{e[:on]} #{e[:at]}")
  record = CalendarEvent.local.find_or_initialize_by(title: e[:title], starts_at: starts_at)
  next unless record.new_record?

  record.update!(
    starts_at: starts_at,
    ends_at:   e[:duration].to_i.positive? ? starts_at + e[:duration].minutes : starts_at,
    all_day:   false,
    recurring: false,
    location:  e[:location],
    notes:     e[:notes],
    calendar_name: "Church Calendar",
    source:    "local",
    synced_at: Time.current
  )
  created += 1
end

puts "demo calendar: #{created} invented events added (#{CalendarEvent.local.count} total local)"
