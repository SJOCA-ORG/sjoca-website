class CreateLegacyAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :legacy_assets do |t|
      # Semantic name tying this asset to a position on the site, e.g.
      # "home-hero", "leadership-fr-david". Deliberately NOT unique: new
      # versions are appended as new rows and the newest published row wins,
      # so a photo can be refreshed without touching any page.
      t.string :human_name, null: false

      t.binary  :data,         null: false
      t.string  :content_type, null: false
      t.integer :byte_size,    null: false

      # Lets the seed be re-run safely: identical bytes for the same name are
      # skipped rather than inserted as a spurious new "version".
      t.string :sha256, null: false

      t.string :source_url
      t.text   :alt_text
      t.string :status, null: false, default: "published"

      t.timestamps
    end

    add_index :legacy_assets, %i[human_name created_at]
    add_index :legacy_assets, %i[human_name sha256], unique: true
  end
end
