# The last of the Ruby that knew what a church service was.
#
# Three mirrors used to run on cron: the ChurchTrac calendar into
# calendar_events, the daily readings into lectionary_days/_readings, the class
# recordings into class_recordings. Each had an importer that knew which events
# mattered and what they were called -- and that knowledge was invisible to the
# AI, which is how a page once shipped missing Vespers and the Divine Liturgy.
#
# They were replaced by one primitive: a data source is a row with a name and a
# URL, the server fetches it behind Site::OutboundFetch, and the page gets JSON
# that admin-written JavaScript formats. The models went first, then the cron
# jobs. These five tables are what is left -- 315 rows nothing reads.
#
# Dropping them now because every table in this database is about to be scoped
# to an organization, and there is no sense teaching dead tables to belong to
# somebody.
class DropTheMirrorTables < ActiveRecord::Migration[8.1]
  TABLES = %w[
    lectionary_readings
    lectionary_days
    calendar_events
    calendar_syncs
    class_recordings
  ].freeze

  def up
    TABLES.each { |t| drop_table(t, if_exists: true) }
  end

  # Deliberately not reversible. Recreating empty tables would restore the
  # shape and not the data, which is worse than saying so plainly: these were
  # caches of outside systems, and the only real way back is a dump.
  def down
    raise ActiveRecord::IrreversibleMigration,
          "These were mirrors of ChurchTrac, oca.org and YouTube. Restore from a " \
          "database dump taken before 27 October 2026, or re-add them as data sources."
  end
end
