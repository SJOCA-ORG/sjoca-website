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

NAV = [
  # slug,                             nav label,            parent,            pos
  ["home",                            "Home",               nil,               1],
  ["about-us",                        "About Us",           nil,               2],
  ["about-us/our-story",              "Our Story",          "about-us",        1],
  ["about-us/leadership",             "Leadership",         "about-us",        2],
  ["about-us/choir",                  "Choir",              "about-us",        3],
  ["events-services",                 "Events & Services",  nil,               3],
  ["events-services/weekly-bulletin", "Weekly Bulletin",    "events-services", 1],
  ["events-services/miter-ceremony",  "Miter Ceremony",     "events-services", 2],
  ["donate",                          "Donate",             nil,               4],
  ["community-outreach",              "Community Outreach", nil,               5],
  ["contact",                         "Contact",            nil,               6]
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
    hero_size:       data["hero_size"] || "standard"
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

puts "pages: #{created} created, #{rebuilt} rebuilt, #{untouched} left alone" \
     "#{untouched.positive? && !force ? ' (FORCE_CONTENT_RESEED=1 to rebuild)' : ''}"
puts "        #{Section.count} sections, #{Block.count} blocks"
