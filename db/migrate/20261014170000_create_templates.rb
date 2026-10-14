# Liquid templates, stored as rows so the parish can change how the site looks
# without a deploy. Versioned with the revision they belong to, exactly like
# pages, sections and blocks.
class CreateTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :templates do |t|
      t.bigint :revision_id, null: false
      t.string :name,        null: false   # "page", "block/heading", "partial/nav"
      t.text   :source,      null: false, default: ""
      t.timestamps
    end
    add_index :templates, %i[revision_id name], unique: true
  end
end
