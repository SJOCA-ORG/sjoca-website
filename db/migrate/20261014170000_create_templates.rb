# Liquid templates, stored as rows so the parish can change how the site looks
# without a deploy. Versioned with the revision they belong to, exactly like
# pages, sections and blocks.
class CreateTemplates < ActiveRecord::Migration[8.1]
  def up
    create_table :templates do |t|
      t.bigint :revision_id, null: false
      t.string :name,        null: false   # "page", "block/heading", "partial/nav"
      t.text   :source,      null: false, default: ""
      t.timestamps
    end
    add_index :templates, %i[revision_id name], unique: true

    # The table is useless empty: the site renders FROM these, so a deploy that
    # created the table and stopped would leave every page unable to render.
    # Install the defaults into every revision that exists.
    say_with_time "installing default templates" do
      require Rails.root.join("db/seeds/templates")
      Revision.reset_column_information
      Revision.find_each { |r| DefaultTemplates.install!(r) }
      Revision.count
    end
  rescue LoadError => e
    say "COULD NOT install default templates: #{e.message}"
    say "Run DefaultTemplates.install! for each revision before serving traffic."
  end

  def down
    drop_table :templates
  end
end
