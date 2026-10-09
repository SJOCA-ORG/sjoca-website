class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.string  :slug,        null: false   # "home", "about-us/our-story"
      t.string  :title,       null: false
      t.string  :nav_title,   null: false   # label in the navigation
      t.string  :parent_slug                # nil for top-level
      t.integer :position,    null: false, default: 0
      t.boolean :show_in_nav, null: false, default: true

      t.string :hero_asset_name             # legacy_assets.human_name
      t.string :hero_heading
      t.string :hero_subheading
      t.string :hero_size, null: false, default: "standard" # standard | tall

      t.timestamps
    end
    add_index :pages, :slug, unique: true
    add_index :pages, %i[parent_slug position]
  end
end
