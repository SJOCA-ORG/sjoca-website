# The typefaces belong to the site, not to the code.
#
# Cormorant Garamond, Lato, Quicksand and Lobster were named in the layout, so
# every site this code ever runs would load them whether it wanted them or not
# — and the parish could not change its own lettering without a developer.
#
# They move into the head template, beside the structured data, where a parish
# can change them by asking.
class MoveFontsIntoTheHeadTemplate < ActiveRecord::Migration[8.1]
  FONTS = <<~HTML
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@1,400;1,500&family=Lato:wght@300;400;700&family=Quicksand:wght@400;500;600&family=Lobster&display=swap">
  HTML

  def up
    rows = select_all("SELECT id, source FROM templates WHERE name = 'head'")
    rows.each do |row|
      next if row["source"].to_s.include?("fonts.googleapis.com")

      execute(<<~SQL)
        UPDATE templates
           SET source = #{quote(FONTS + row['source'].to_s)}, updated_at = #{quote(Time.current)}
         WHERE id = #{row['id'].to_i}
      SQL
    end
  end

  def down
    execute("UPDATE templates SET source = replace(source, #{quote(FONTS)}, '') WHERE name = 'head'")
  end
end
