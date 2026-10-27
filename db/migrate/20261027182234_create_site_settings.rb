class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.bigint :revision_id, null: false
      t.string :key, null: false
      t.text :value
      t.timestamps
    end

    # Per revision, like everything else that makes up the site: changing the
    # parish's address is a change to the site, and should be published and
    # rolled back with the rest of it.
    add_index :site_settings, %i[revision_id key], unique: true
  end
end
