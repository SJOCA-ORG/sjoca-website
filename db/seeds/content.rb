# Seeds pages, sections and blocks from db/seeds/content.yml, which is produced
# by script/extract_current_site.rb from the captured Google Sites DOM.
#
# SAFETY: this rebuilds a page's sections and blocks from scratch. Once the
# Phase 2 CMS exists, that would wipe anything a parishioner had edited -- and
# deploys run seeds repeatedly. So an existing page is left alone unless you
# explicitly ask for it:
#
#   FORCE_CONTENT_RESEED=1 bin/rails db:seed
#
# Think of this as the import of the old site, not as a content migration tool.

# The fourth column, where present, is the label the parent takes as the first
# item in its own submenu — so a visitor can tell the parent has a page too.
SELF_NAV = {
  "events-services" => "Calendar",
  "education"       => "Adult Education"
}.freeze

NAV = [
  # slug,                             nav label,            parent,            pos
  ["home",                            "Home",               nil,               1],
  ["about-us",                        "About Us",           nil,               2],
  ["about-us/our-story",              "Our Story",          "about-us",        1],
  ["about-us/leadership",             "Leadership",         "about-us",        2],
  ["about-us/choir",                  "Choir",              "about-us",        3],
  ["events-services",                 "Events & Services",  nil,               3],
  ["events-services/weekly-bulletin", "Weekly Bulletin",    "events-services", 1],
  ["education",                       "Education & Resources", nil,            4],
  ["education/daily-lectionary",      "Daily Lectionary",   "education",       1],
  ["education/orthodox-resources",    "Orthodox Resources", "education",       2],
  ["donate",                          "Giving",             nil,               5],
  ["community-outreach",              "Community Outreach", nil,               6],
  ["contact",                         "Contact",            nil,               7]
].freeze

force   = ENV["FORCE_CONTENT_RESEED"] == "1"
content = YAML.load_file(Rails.root.join("db/seeds/content.yml")).index_by { |p| p["slug"] }

created = rebuilt = untouched = 0

NAV.each do |slug, nav_title, parent, position|
  data = content[slug] or next
  page = Page.find_by(slug: slug)

  if page && !force
    untouched += 1
    next
  end

  if page
    rebuilt += 1
  else
    page = Page.new(slug: slug)
    created += 1
  end

  page.assign_attributes(
    title:           ActionView::Base.full_sanitizer.sanitize(data["hero_heading"].to_s).presence || nav_title,
    nav_title:       nav_title,
    parent_slug:     parent,
    position:        position,
    hero_asset_name: data["hero_asset_name"],
    hero_heading:    data["hero_heading"],
    hero_subheading: data["hero_subheading"],
    hero_detail:     data["hero_detail"],
    hero_size:       data["hero_size"] || "standard",
    self_nav_title:  SELF_NAV[slug]
  )
  page.save!
  page.sections.destroy_all

  data["sections"].each_with_index do |s, i|
    section = page.sections.create!(position: i, style: s["style"],
                                    column_widths: s["column_widths"])
    s["blocks"].each do |b|
      section.blocks.create!(
        row:        b["row"]      || 0,
        column:     b["column"]   || 0,
        position:   b["position"] || 0,
        kind:       b["kind"],
        content:    b["content"],
        asset_name: b["asset_name"],
        url:        b["url"],
        align:      b["align"] || "left",
        width:      b["width"]
      )
    end
  end
end

# A page removed from NAV lingers in the database otherwise: renaming a slug
# leaves the old row behind, still in the navigation, still reachable. That
# happened twice -- Miter Ceremony and adult-education -- and both had to be
# deleted by hand.
#
# Only prune on an explicit re-import. Once the Phase 2 CMS can create pages,
# deleting anything not in this list would be destructive, so this needs
# revisiting then.
orphans = Page.where.not(slug: NAV.map(&:first))
if orphans.any?
  if force
    orphans.each { |p| puts "   removing #{p.slug} (no longer in NAV)" }
    orphans.destroy_all
  else
    puts "   !! #{orphans.count} page(s) in the database but not in NAV: " \
         "#{orphans.pluck(:slug).join(', ')}"
    puts "   !! FORCE_CONTENT_RESEED=1 to remove them"
  end
end

puts "pages: #{created} created, #{rebuilt} rebuilt, #{untouched} left alone" \
     "#{untouched.positive? && !force ? ' (FORCE_CONTENT_RESEED=1 to rebuild)' : ''}"
puts "        #{Section.count} sections, #{Block.count} blocks"
