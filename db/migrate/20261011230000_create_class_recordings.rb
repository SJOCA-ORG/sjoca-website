class CreateClassRecordings < ActiveRecord::Migration[8.1]
  def change
    create_table :class_recordings do |t|
      t.string  :youtube_id, null: false
      t.string  :title,      null: false
      t.integer :number                  # "#3 Catechumen Class" -> 3
      t.date    :held_on                 # parsed out of the title
      t.integer :position, null: false, default: 0   # order within the playlist
      t.datetime :synced_at, null: false

      t.timestamps
    end
    add_index :class_recordings, :youtube_id, unique: true
    add_index :class_recordings, :held_on
  end
end
