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
    puts "range:         #{CalendarEvent.minimum(:starts_at)&.to_date} .. #{CalendarEvent.maximum(:starts_at)&.to_date}" if CalendarEvent.any?
    puts "last sync:     #{last ? "#{last.created_at} (#{last.status})" : 'never'}"
    puts "stale?:        #{CalendarSync.stale? ? 'YES — nothing successful in 2 days' : 'no'}"
    puts
    puts "next services:"
    CalendarEvent.next_services(5).each { |e| puts "   #{e.when_text} — #{e.title}" }
  end
end

namespace :classes do
  desc "Mirror the adult education playlist into class_recordings"
  task sync: :environment do
    result = YouTube::RecordingImporter.new.call
    puts "status:  #{result.status}"
    puts "fetched: #{result.fetched}"
    puts "created: #{result.created}, updated: #{result.updated}, removed: #{result.removed}"
    puts "message: #{result.message}" if result.message
    abort("class recording sync did not succeed") unless result.status == "ok"
  end
end

namespace :lectionary do
  desc "Mirror the daily scripture readings from oca.org (today + 21 days)"
  task sync: :environment do
    result = Oca::LectionaryImporter.new.call
    puts "status:  #{result.status}"
    puts "created: #{result.created}, already had: #{result.skipped}, failed: #{result.failed}"
    puts "last error: #{result.message}" if result.message
    abort("lectionary sync did not succeed") unless result.status == "ok"
  end

  desc "Show what the lectionary mirror holds"
  task status: :environment do
    puts "days: #{LectionaryDay.count} (#{LectionaryDay.upcoming.count} upcoming)"
    puts "range: #{LectionaryDay.minimum(:on)} .. #{LectionaryDay.maximum(:on)}" if LectionaryDay.any?
    puts
    LectionaryDay.for_week.each do |d|
      puts "  #{d.date_text}"
      d.appointed.each { |x| puts "      #{x.label}" }
      puts "      #{d.commemorations.to_s[0, 86]}..." if d.commemorations
    end
  end
end
