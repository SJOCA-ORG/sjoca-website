class CreateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :blocks do |t|
      t.references :section, null: false, foreign_key: true

      t.integer :row,      null: false, default: 0  # grid row within the section
      t.integer :column,   null: false, default: 0  # cell within that row
      t.integer :position, null: false, default: 0  # order within the cell

      # heading | subheading | text | image | embed | button
      t.string :kind, null: false

      t.text   :content      # text/HTML for text-ish blocks
      t.string :asset_name   # legacy_assets.human_name for images
      t.string :url          # link target, or embed src
      t.string :align, null: false, default: "left"

      t.timestamps
    end
    add_index :blocks, %i[section_id row column position]
  end
end
