class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :page, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      # Matches the banding of the current site:
      #   plain  -> white
      #   light  -> #E9E9E9 band
      #   maroon -> #6D0606 band, light text
      t.string :style, null: false, default: "plain"

      t.timestamps
    end
    add_index :sections, %i[page_id position]
  end
end
