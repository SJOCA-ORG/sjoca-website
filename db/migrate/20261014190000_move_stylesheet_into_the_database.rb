# The site's stylesheet becomes a database row, so the parish can change how the
# site looks rather than only layer overrides on top of a file it cannot reach.
#
# Overriding is easy; UN-setting is awkward — you write a counter-rule and reach
# for !important, and that is what accumulates into a mess over a few seasons.
# Editing the real stylesheet avoids the layering entirely.
#
# Safety comes from the revision, not from the file being read-only: a bad
# stylesheet is previewed before it is published and undone by republishing.
class MoveStylesheetIntoTheDatabase < ActiveRecord::Migration[8.1]
  SOURCE = Rails.root.join("app/assets/stylesheets/application.css")

  def up
    return unless SOURCE.exist?

    css = SOURCE.read
    say_with_time "seeding site.css (#{(css.bytesize / 1024.0).round(1)} KB) into every revision" do
      Revision.reset_column_information
      Revision.find_each do |revision|
        asset = ThemeAsset.find_or_initialize_by(revision: revision, name: "site.css")
        asset.update!(content: css) if asset.content.blank?
      end
      Revision.count
    end
  end

  def down
    ThemeAsset.where(name: "site.css").delete_all
  end
end
