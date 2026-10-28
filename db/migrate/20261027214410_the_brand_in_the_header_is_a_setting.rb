# "SJTB" was written into the header template.
#
# Which was fine while the template was ERB in this repository and there was one
# parish. It is not fine now: templates are seeded into every NEW organization
# from db/seeds/templates.rb, so the first organization anybody created would
# have shipped with this parish's monogram at the top of every page.
#
# The same trap as SiteDrop::FALLBACK, in a file nobody thought to check --
# spec/requests/no_parish_in_ruby_spec.rb reads the code a visitor is served and
# never looked at db/seeds.
#
# So the monogram becomes what it always was: a fact about one organization.
# Stored as a setting, with a fallback chain, and backfilled here so the
# rendered header does not change by a single byte.
class TheBrandInTheHeaderIsASetting < ActiveRecord::Migration[8.1]
  OLD = '<a class="site-header__brand" href="/">SJTB</a>'
  NEW = '<a class="site-header__brand" href="/">' \
        '{{ site.settings.brand | default: site.settings.short_name | default: site.name }}</a>'

  def up
    # The setting first, or there is a moment where the template asks for
    # something that is not there and the header grows the full long name.
    now = Time.current
    revisions = select_values("SELECT id FROM revisions")
    revisions.each do |id|
      next if select_value("SELECT 1 FROM site_settings WHERE revision_id = #{id} AND key = 'brand'")

      execute(<<~SQL)
        INSERT INTO site_settings (revision_id, key, value, created_at, updated_at)
        VALUES (#{id}, 'brand', 'SJTB', #{quote(now)}, #{quote(now)})
      SQL
    end
    say "brand set on #{revisions.size} revision(s)"

    changed = 0
    select_all("SELECT id, source FROM templates WHERE name = 'header'").each do |row|
      next unless row["source"].include?(OLD)

      execute "UPDATE templates SET source = #{quote(row['source'].sub(OLD, NEW))} WHERE id = #{row['id']}"
      changed += 1
    end
    say "header template rewritten in #{changed} revision(s)"
  end

  def down
    select_all("SELECT id, source FROM templates WHERE name = 'header'").each do |row|
      next unless row["source"].include?(NEW)

      execute "UPDATE templates SET source = #{quote(row['source'].sub(NEW, OLD))} WHERE id = #{row['id']}"
    end
    execute "DELETE FROM site_settings WHERE key = 'brand'"
  end
end
