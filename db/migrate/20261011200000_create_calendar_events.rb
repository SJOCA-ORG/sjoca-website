class CreateCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_events do |t|
      # ChurchTrac identifies a recurring SERIES with `id` and `UID` (they are
      # 1:1). A single occurrence is the series plus its start, which is unique
      # across the whole feed — so that pair is our natural key and what makes
      # re-syncing idempotent rather than duplicating.
      t.string   :churchtrac_id, null: false
      t.string   :uid
      t.datetime :starts_at,     null: false
      t.datetime :ends_at

      t.string  :title, null: false
      t.boolean :all_day,   null: false, default: false
      t.boolean :recurring, null: false, default: false
      t.string  :location
      t.text    :notes
      t.string  :calendar_name

      t.datetime :synced_at, null: false

      t.timestamps
    end

    add_index :calendar_events, %i[churchtrac_id starts_at], unique: true
    add_index :calendar_events, :starts_at
  end
end
