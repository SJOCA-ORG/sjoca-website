# One-off: move what the parish IS out of Ruby and into a template it owns.
#
# Site::Seo asserted the name, the address, the fact that this is a Church, and
# the service times -- the last filtered out of the ChurchTrac feed by a list of
# title patterns in Ruby. Nobody could read that filter, and it was wrong: the
# Hours at 9:30 on Sunday are on the home page and were missing from what Google
# was told.
#
# The same words now live in a "head" template in each revision, where they can
# be read, corrected, and changed by asking. Ruby no longer knows this is a
# church.
SOURCE = <<~LIQUID
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

written = 0
Revision.where.not(state: "discarded").find_each do |rev|
  next if rev.templates.exists?(name: "head")
  next if rev.templates.none?          # a revision with no templates renders nothing anyway

  rev.templates.create!(name: "head", source: SOURCE)
  written += 1
  puts "  added head to revision #{rev.id} (#{rev.state})"
end
puts "done — #{written} revisions"
