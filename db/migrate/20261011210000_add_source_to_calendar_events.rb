class AddSourceToCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    # Where an event came from. The importer treats ChurchTrac as authoritative
    # inside its window and deletes anything there it no longer sees — so
    # anything created locally needs to be exempt, or it would vanish on the
    # next sync. Also leaves room for the parish to add site-only entries later.
    add_column :calendar_events, :source, :string, null: false, default: "churchtrac"
    add_index  :calendar_events, :source

    # churchtrac_id is only unique per source; a local event has none.
    change_column_null :calendar_events, :churchtrac_id, true
  end
end
