class CreateDataSources < ActiveRecord::Migration[8.1]
  def change
    # The DEFINITION of an outside data source belongs to a revision: it is
    # content the AI writes, it must be previewable, and it must roll back with
    # everything else. So it is copied when a sandbox is opened, like templates.
    create_table :data_sources do |t|
      t.references :revision, null: false, foreign_key: true
      t.string :name, null: false
      t.json :urls, null: false, default: []
      t.integer :refresh_minutes, null: false, default: 60
      t.text :note
      t.timestamps
      t.index %i[revision_id name], unique: true
    end

    # The CACHED RESPONSE does not. It is keyed by URL and shared by every
    # revision that asks for the same address -- otherwise a megabyte of fetched
    # HTML would be duplicated into every sandbox anyone opens.
    create_table :fetched_pages do |t|
      t.string :key, null: false            # sha256 of the url
      t.text :url, null: false
      t.text :body
      t.string :content_type
      t.integer :status
      t.text :error
      t.datetime :fetched_at
      t.timestamps
      t.index :key, unique: true
    end
  end
end
