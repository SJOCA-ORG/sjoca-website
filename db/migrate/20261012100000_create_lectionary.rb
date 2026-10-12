class CreateLectionary < ActiveRecord::Migration[8.1]
  def change
    create_table :lectionary_days do |t|
      t.date     :on,             null: false
      t.string   :title                        # "Monday, October 12, 2026"
      t.text     :commemorations               # saints and feasts for the day
      t.datetime :synced_at,      null: false
      t.timestamps
    end
    add_index :lectionary_days, :on, unique: true

    create_table :lectionary_readings do |t|
      t.references :lectionary_day, null: false, foreign_key: true
      t.integer :position, null: false         # order on the OCA page
      t.string  :citation, null: false         # "Luke 7:36-50"
      t.string  :kind                          # "Gospel", "Epistle", ...
      t.text    :body                          # verse-numbered text
      t.string  :source_url
      t.timestamps
    end
    add_index :lectionary_readings, %i[lectionary_day_id position], unique: true
  end
end
