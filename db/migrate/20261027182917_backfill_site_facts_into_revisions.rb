# Move what the parish IS out of Ruby and into every revision.
#
# This MUST run with the deploy that removes the constants, not after it. The
# code it accompanies falls back to "This site" when a revision has no settings
# -- correct for a parish that has not been configured, catastrophic for one
# that has, which would find its own name gone from every page.
#
# Written against the tables rather than the models: a migration that calls a
# model breaks the day somebody renames a method, long after anyone remembers
# this ran.
class BackfillSiteFactsIntoRevisions < ActiveRecord::Migration[8.1]
  FACTS = {
    "name" => "Saint John the Baptist Orthodox Church",
    "short_name" => "St John the Baptist Orthodox Church",
    "address" => "855 S. Goodman St. Rochester, NY 14620",
    "email" => "fr.david@sjoca.org",
    "city" => "Rochester",
    "region" => "NY",
    "description" => "Saint John the Baptist Orthodox Church in Rochester, NY — a parish of the " \
                     "Orthodox Church in America (OCA), Diocese of New York and New Jersey. " \
                     "Services entirely in English. All are welcome."
  }.freeze

  # What Site::Seo used to build in Ruby, as a template the parish owns.
  #
  # The service times are STATED here, and include the Hours at 9:30 on a
  # Sunday. The Ruby filter they replace dropped those: they are on the home
  # page and were missing from what Google was told, because they did not match
  # a pattern nobody could see.
  HEAD = <<~LIQUID
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Church",
      "name": "Saint John the Baptist Orthodox Church",
      "alternateName": "St John the Baptist Orthodox Church",
      "description": "Saint John the Baptist Orthodox Church in Rochester, NY — a parish of the Orthodox Church in America (OCA), Diocese of New York and New Jersey. Services entirely in English. All are welcome.",
      "url": "{{ site.url }}",
      "email": "{{ site.email }}",
      "address": {
        "@type": "PostalAddress",
        "streetAddress": "855 S. Goodman St.",
        "addressLocality": "Rochester",
        "addressRegion": "NY",
        "postalCode": "14620",
        "addressCountry": "US"
      },
      "parentOrganization": {
        "@type": "Organization",
        "name": "Orthodox Church in America",
        "url": "https://www.oca.org"
      },
      "openingHoursSpecification": [
        { "@type": "OpeningHoursSpecification", "dayOfWeek": "https://schema.org/Saturday",  "opens": "18:00", "closes": "19:30", "name": "Great Vespers" },
        { "@type": "OpeningHoursSpecification", "dayOfWeek": "https://schema.org/Sunday",    "opens": "09:30", "closes": "11:30", "name": "The Hours and Divine Liturgy" },
        { "@type": "OpeningHoursSpecification", "dayOfWeek": "https://schema.org/Wednesday", "opens": "18:00", "closes": "19:30", "name": "Evening Prayers" }
      ]
    }
    </script>
  LIQUID

  def up
    now = Time.current

    revisions = select_all("SELECT id FROM revisions WHERE state <> 'discarded'").rows.flatten
    revisions.each do |revision_id|
      FACTS.each do |key, value|
        next if select_value("SELECT 1 FROM site_settings WHERE revision_id = #{revision_id.to_i} AND key = #{quote(key)}")

        execute(<<~SQL)
          INSERT INTO site_settings (revision_id, key, value, created_at, updated_at)
          VALUES (#{revision_id.to_i}, #{quote(key)}, #{quote(value)}, #{quote(now)}, #{quote(now)})
        SQL
      end

      # Only where there are templates at all: a revision with none renders
      # nothing anyway, and giving it one would be noise.
      next unless select_value("SELECT 1 FROM templates WHERE revision_id = #{revision_id.to_i}")
      next if select_value("SELECT 1 FROM templates WHERE revision_id = #{revision_id.to_i} AND name = 'head'")

      execute(<<~SQL)
        INSERT INTO templates (revision_id, name, source, created_at, updated_at)
        VALUES (#{revision_id.to_i}, 'head', #{quote(HEAD)}, #{quote(now)}, #{quote(now)})
      SQL
    end
  end

  def down
    execute("DELETE FROM site_settings")
    execute("DELETE FROM templates WHERE name = 'head'")
  end
end
