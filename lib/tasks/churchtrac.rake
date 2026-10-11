namespace :churchtrac do
  desc "Mirror the ChurchTrac calendar into calendar_events (1 month back, 12 forward)"
  task sync: :environment do
    result = ChurchTrac::CalendarImporter.new.call

    puts "status:  #{result.status}"
    puts "fetched: #{result.fetched}"
    puts "created: #{result.created}, updated: #{result.updated}, removed: #{result.removed}"
    puts "message: #{result.message}" if result.message

    # Non-zero exit so a cron wrapper or CI notices, rather than failing quietly.
    abort("calendar sync did not succeed") unless result.status == "ok"
  end

  desc "Show what the mirror currently holds"
  task status: :environment do
    last = CalendarSync.recent.first
    puts "events:        #{CalendarEvent.count} (#{CalendarEvent.upcoming.count} upcoming)"
    if (range = CalendarEvent.pluck(Arel.sql("MIN(starts_at), MAX(starts_at)")).first)
      puts "range:         #{range[0]&.to_date} .. #{range[1]&.to_date}"
    end
    puts "last sync:     #{last ? "#{last.created_at} (#{last.status})" : 'never'}"
    puts "stale?:        #{CalendarSync.stale? ? 'YES — nothing successful in 2 days' : 'no'}"
    puts
    puts "next services:"
    CalendarEvent.next_services(5).each { |e| puts "   #{e.when_text} — #{e.title}" }
  end
end
