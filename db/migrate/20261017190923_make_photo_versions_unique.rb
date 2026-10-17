# A photo reference is a PAIR -- the name and the version -- and that pair is
# what makes rolling back honest: a page says exactly which image it meant.
#
# Nothing enforced it. The unique index was on [human_name, sha256], so two
# DIFFERENT images could both be "leadership-dn-mitch version 1", and three of
# them were. find_version does a find_by, so which one rendered was whatever
# Postgres returned first.
#
# That is not hypothetical. The deployed site served the altar close-up for
# that pair; the same pair on a developer machine served the ordination
# vesting photo. Same name, same version, two different photographs of two
# different occasions, and no way to ask for the one you meant.
class MakePhotoVersionsUnique < ActiveRecord::Migration[8.1]
  def up
    # Renumber chronologically: the oldest image of a name is version 1. Only
    # names that actually collide are touched.
    say_with_time "renumbering duplicate versions" do
      duplicates = select_rows(<<~SQL)
        SELECT human_name FROM photos
        GROUP BY human_name, version HAVING count(*) > 1
      SQL

      duplicates.flatten.uniq.each do |name|
        rows = select_rows("SELECT id FROM photos WHERE human_name = #{quote(name)} ORDER BY created_at, id")
        rows.flatten.each_with_index do |id, i|
          execute "UPDATE photos SET version = #{i + 1} WHERE id = #{id}"
        end
        say "#{name}: #{rows.size} images renumbered 1..#{rows.size}", true
      end
      duplicates.size
    end

    # References pointed at version 1, which resolved to a different image in
    # different places. Point them at the NEWEST version of their name: that is
    # the image the deployed site has been showing, so this makes every
    # environment agree with what people have actually seen.
    say_with_time "repointing references to the newest version" do
      execute <<~SQL
        UPDATE blocks b SET asset_version = newest.version
        FROM (SELECT human_name, max(version) AS version FROM photos GROUP BY human_name) newest
        WHERE b.asset_name = newest.human_name
          AND (b.asset_version IS NULL OR b.asset_version <> newest.version)
      SQL
      execute <<~SQL
        UPDATE pages p SET hero_asset_version = newest.version
        FROM (SELECT human_name, max(version) AS version FROM photos GROUP BY human_name) newest
        WHERE p.hero_asset_name = newest.human_name
          AND (p.hero_asset_version IS NULL OR p.hero_asset_version <> newest.version)
      SQL
    end

    remove_index :photos, column: %i[human_name version], if_exists: true
    add_index :photos, %i[human_name version], unique: true
  end

  def down
    remove_index :photos, column: %i[human_name version]
    add_index :photos, %i[human_name version]
  end
end
