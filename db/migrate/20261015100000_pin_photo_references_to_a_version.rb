# A photograph reference becomes a PAIR: the slug and the version.
#
# Before this, a reference was a bare slug and the newest published row won. That
# is an inference, and it made rolling back dishonest: restoring last month's
# words kept this month's pictures. It also meant a page could not tell you which
# photograph it would show.
#
# Now a template says ("christmas-pageant", 101) and keeps saying it as the
# revision is copied forward. Replacing the photograph is an EDIT -- a new row at
# the current revision, and the reference pointed at it. Wanting last year's back
# is another edit pointing at 101, which is still there.
#
# What this gives up is "replace a photograph without touching any page". That
# was invisible magic: you could not tell from a page which picture it would
# show, and a swap changed pages nobody had edited. Replacing everywhere is now
# a real operation that appears in the change log as the edits it actually is.
class PinPhotoReferencesToAVersion < ActiveRecord::Migration[8.1]
  def up
    add_column :photos, :version, :integer
    add_index  :photos, %i[human_name version]

    add_column :blocks, :asset_version,      :integer
    add_column :pages,  :hero_asset_version, :integer

    say_with_time "stamping existing photographs and references" do
      first = select_value("SELECT MIN(id) FROM revisions") || 1
      execute "UPDATE photos SET version = #{first} WHERE version IS NULL"

      # Every existing reference means "whatever that slug resolved to", which
      # was the newest row. Point them all at it explicitly.
      execute <<~SQL
        UPDATE blocks SET asset_version = p.version
        FROM (SELECT DISTINCT ON (human_name) human_name, version
              FROM photos WHERE status = 'published'
              ORDER BY human_name, created_at DESC, id DESC) p
        WHERE blocks.asset_name = p.human_name
      SQL
      execute <<~SQL
        UPDATE pages SET hero_asset_version = p.version
        FROM (SELECT DISTINCT ON (human_name) human_name, version
              FROM photos WHERE status = 'published'
              ORDER BY human_name, created_at DESC, id DESC) p
        WHERE pages.hero_asset_name = p.human_name
      SQL
      select_value("SELECT COUNT(*) FROM photos")
    end

    change_column_null :photos, :version, false
  end

  def down
    remove_column :pages,  :hero_asset_version
    remove_column :blocks, :asset_version
    remove_column :photos, :version
  end
end
