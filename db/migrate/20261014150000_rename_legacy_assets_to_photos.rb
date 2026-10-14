# "Legacy" described the migration off Google Sites, which nobody will remember
# in a year. The table holds the parish's photographs; it should say so.
#
# Only the table is renamed. The referencing columns (blocks.asset_name,
# pages.hero_asset_name) keep their names: they do not say "legacy", and renaming
# them would mean rewriting 30 keys in db/seeds/content.yml for no real gain.
#
# The public URL is /media/:human_name and does not contain the table name, so
# nothing user-facing changes and no links break.
class RenameLegacyAssetsToPhotos < ActiveRecord::Migration[8.1]
  def change
    rename_table :legacy_assets, :photos
  end
end
