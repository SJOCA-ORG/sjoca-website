# A revision is the sandbox. Not a branch, not a second deployment -- a set of
# rows. The live site renders the published revision; a preview renders any
# other. See docs/ai-admin.md.
#
# Revisions are full copies rather than deltas. That sounds expensive until you
# count: this site is 13 pages, 36 sections and 122 blocks. Deltas would save
# nothing and would make deletion need tombstones and every query need a
# fallback join.
#
# Photographs are the exception and are never copied: `photos` is ~32MB and
# already versions itself, and blocks reference a photo by human_name.
class CreateRevisions < ActiveRecord::Migration[8.1]
  def up
    create_table :revisions do |t|
      t.string   :state,   null: false, default: "draft"   # draft | published | superseded
      t.string   :title
      t.string   :created_by
      t.bigint   :based_on_id
      t.datetime :published_at
      t.timestamps
    end
    add_index :revisions, :state

    # CSS and JS the parish can change without a deploy. Appended after the
    # compiled stylesheet, so it overrides rather than replaces.
    create_table :theme_assets do |t|
      t.bigint :revision_id, null: false
      t.string :name,        null: false
      t.text   :content
      t.timestamps
    end
    add_index :theme_assets, %i[revision_id name], unique: true

    # The conversation. Persisting rows is not enough: without this the AI
    # cannot resolve "move it back up a bit" after a reload, and the feature
    # works on day one and is useless on day two.
    create_table :revision_messages do |t|
      t.bigint :revision_id, null: false
      t.string :role,        null: false       # user | assistant
      t.text   :content
      t.json   :tool_calls
      t.timestamps
    end
    add_index :revision_messages, %i[revision_id created_at]

    %i[pages sections blocks].each do |table|
      add_column table, :revision_id, :bigint
      add_index  table, :revision_id
    end

    # A slug was globally unique, which is wrong the moment a second revision
    # exists: a slug necessarily repeats across revisions -- that is what a
    # revision *is*. Unique within a revision instead.
    remove_index :pages, :slug
    add_index    :pages, %i[revision_id slug], unique: true

    # Everything that exists today becomes revision 1, already published.
    say_with_time "adopting existing content as revision 1" do
      execute <<~SQL
        INSERT INTO revisions (state, title, created_by, published_at, created_at, updated_at)
        VALUES ('published', 'Phase 1 clone, as built', 'migration', NOW(), NOW(), NOW())
      SQL
      id = select_value("SELECT id FROM revisions ORDER BY id DESC LIMIT 1")
      %i[pages sections blocks].each { |t| execute "UPDATE #{t} SET revision_id = #{id}" }
      id
    end

    change_column_null :pages,    :revision_id, false
    change_column_null :sections, :revision_id, false
    change_column_null :blocks,   :revision_id, false
  end

  def down
    remove_index :pages, %i[revision_id slug]
    %i[pages sections blocks].each { |t| remove_column t, :revision_id }
    add_index :pages, :slug, unique: true
    drop_table :revision_messages
    drop_table :theme_assets
    drop_table :revisions
  end
end
