class CreateCalendarSyncs < ActiveRecord::Migration[8.1]
  def change
    # A record of every sync attempt. Without this, a sync that quietly stops
    # working looks exactly like a parish with no events scheduled — which is a
    # confusion worth engineering against, given we already fooled ourselves
    # once about this very calendar.
    create_table :calendar_syncs do |t|
      t.string   :status, null: false          # ok | failed | refused
      t.datetime :window_start
      t.datetime :window_end
      t.integer  :fetched, null: false, default: 0
      t.integer  :created, null: false, default: 0
      t.integer  :updated, null: false, default: 0
      t.integer  :removed, null: false, default: 0
      t.text     :message
      t.float    :duration

      t.timestamps
    end
    add_index :calendar_syncs, :created_at
  end
end
