# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_11_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "blocks", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.integer "row", default: 0, null: false
    t.integer "column", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.string "kind", null: false
    t.text "content"
    t.string "asset_name"
    t.string "url"
    t.string "align", default: "left", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "width"
    t.index ["section_id", "row", "column", "position"], name: "index_blocks_on_section_id_and_row_and_column_and_position"
    t.index ["section_id"], name: "index_blocks_on_section_id"
  end

  create_table "calendar_events", force: :cascade do |t|
    t.string "churchtrac_id"
    t.string "uid"
    t.datetime "starts_at", null: false
    t.datetime "ends_at"
    t.string "title", null: false
    t.boolean "all_day", default: false, null: false
    t.boolean "recurring", default: false, null: false
    t.string "location"
    t.text "notes"
    t.string "calendar_name"
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "churchtrac", null: false
    t.index ["churchtrac_id", "starts_at"], name: "index_calendar_events_on_churchtrac_id_and_starts_at", unique: true
    t.index ["source"], name: "index_calendar_events_on_source"
    t.index ["starts_at"], name: "index_calendar_events_on_starts_at"
  end

  create_table "calendar_syncs", force: :cascade do |t|
    t.string "status", null: false
    t.datetime "window_start"
    t.datetime "window_end"
    t.integer "fetched", default: 0, null: false
    t.integer "created", default: 0, null: false
    t.integer "updated", default: 0, null: false
    t.integer "removed", default: 0, null: false
    t.text "message"
    t.float "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_calendar_syncs_on_created_at"
  end

  create_table "legacy_assets", force: :cascade do |t|
    t.string "human_name", null: false
    t.binary "data", null: false
    t.string "content_type", null: false
    t.integer "byte_size", null: false
    t.string "sha256", null: false
    t.string "source_url"
    t.text "alt_text"
    t.string "status", default: "published", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["human_name", "created_at"], name: "index_legacy_assets_on_human_name_and_created_at"
    t.index ["human_name", "sha256"], name: "index_legacy_assets_on_human_name_and_sha256", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.string "slug", null: false
    t.string "title", null: false
    t.string "nav_title", null: false
    t.string "parent_slug"
    t.integer "position", default: 0, null: false
    t.boolean "show_in_nav", default: true, null: false
    t.string "hero_asset_name"
    t.string "hero_heading"
    t.string "hero_subheading"
    t.string "hero_size", default: "standard", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_slug", "position"], name: "index_pages_on_parent_slug_and_position"
    t.index ["slug"], name: "index_pages_on_slug", unique: true
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "page_id", null: false
    t.integer "position", default: 0, null: false
    t.string "style", default: "plain", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "column_widths"
    t.index ["page_id", "position"], name: "index_sections_on_page_id_and_position"
    t.index ["page_id"], name: "index_sections_on_page_id"
  end

  add_foreign_key "blocks", "sections"
  add_foreign_key "sections", "pages"
end
