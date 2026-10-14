# Loads the site as it was at the START of Phase 1 -- the Google Sites clone as
# first captured -- into a new revision, and publishes it.
#
# This is step 1 of the acceptance test in docs/ai-admin.md: roll the site back,
# keep the Ruby widgets, and reproduce everything since through the admin alone.
#
# Nothing is destroyed. The current site stays as a superseded revision and can
# be made live again from the admin at any moment.
#
#   bin/rails runner script/load_baseline_revision.rb

BASELINE = Rails.root.join("db/seeds/baseline/content.yml")

# The navigation as it stood then: Donate rather than Giving, a Miter Ceremony
# page, no Education section, and no parent-lists-itself submenu entries.
NAV = [
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

# The capture named photographs positionally; they were given meaningful names
# shortly afterwards, in the extraction script rather than through the site. The
# bytes are the same, so the baseline points at the names that exist today --
# otherwise three home-page images would simply be missing.
RENAMED = {
  "home-01" => "home-exterior",
  "home-02" => "home-icon-st-john",
  "home-03" => "home-iconostasis"
}.freeze

def photo_name(name) = name && RENAMED.fetch(name, name)

content = YAML.load_file(BASELINE).index_by { |p| p["slug"] }

revision = Revision.create!(
  state: "draft", created_by: "baseline loader",
  title: "Phase 1 start — the Google Sites clone, as captured"
)

NAV.each do |slug, nav_title, parent, position|
  data = content[slug] or next

  page = revision.pages.create!(
    slug: slug,
    title: ActionView::Base.full_sanitizer.sanitize(data["hero_heading"].to_s).presence || nav_title,
    nav_title: nav_title, parent_slug: parent, position: position,
    hero_asset_name: photo_name(data["hero_asset_name"]), hero_heading: data["hero_heading"],
    hero_subheading: data["hero_subheading"], hero_detail: data["hero_detail"],
    hero_size: data["hero_size"] || "standard"
  )

  data["sections"].each_with_index do |s, i|
    section = page.sections.create!(revision: revision, position: i,
                                    style: s["style"], column_widths: s["column_widths"])
    s["blocks"].each do |b|
      section.blocks.create!(
        revision: revision, row: b["row"] || 0, column: b["column"] || 0,
        position: b["position"] || 0, kind: b["kind"], content: b["content"],
        asset_name: photo_name(b["asset_name"]), url: b["url"],
        align: b["align"] || "left", width: b["width"]
      )
    end
  end
end

load Rails.root.join("db/seeds/templates.rb").to_s
DefaultTemplates.install!(revision)

puts "Loaded revision #{revision.id}: #{revision.summary}"
puts "  pages: #{revision.pages.order(:position).pluck(:nav_title).join(', ')}"
puts
puts "To make it live:   bin/rails runner 'Revision.find(#{revision.id}).publish!'"
puts "To look first:     /admin/revisions/#{revision.id}"
