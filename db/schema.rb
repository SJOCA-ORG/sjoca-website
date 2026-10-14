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

ActiveRecord::Schema[8.1].define(version: 2026_10_14_200000) do
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
    t.bigint "revision_id", null: false
    t.string "css_class"
    t.index ["revision_id"], name: "index_blocks_on_revision_id"
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

  create_table "class_recordings", force: :cascade do |t|
    t.string "youtube_id", null: false
    t.string "title", null: false
    t.integer "number"
    t.date "held_on"
    t.integer "position", default: 0, null: false
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["held_on"], name: "index_class_recordings_on_held_on"
    t.index ["youtube_id"], name: "index_class_recordings_on_youtube_id", unique: true
  end

  create_table "lectionary_days", force: :cascade do |t|
    t.date "on", null: false
    t.string "title"
    t.text "commemorations"
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["on"], name: "index_lectionary_days_on_on", unique: true
  end

  create_table "lectionary_readings", force: :cascade do |t|
    t.bigint "lectionary_day_id", null: false
    t.integer "position", null: false
    t.string "citation", null: false
    t.string "kind"
    t.text "body"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lectionary_day_id", "position"], name: "index_lectionary_readings_on_lectionary_day_id_and_position", unique: true
    t.index ["lectionary_day_id"], name: "index_lectionary_readings_on_lectionary_day_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.string "subject", null: false
    t.text "body", null: false
    t.string "learned_in"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "subject"], name: "index_lessons_on_active_and_subject"
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
    t.text "hero_detail"
    t.string "self_nav_title"
    t.bigint "revision_id", null: false
    t.index ["parent_slug", "position"], name: "index_pages_on_parent_slug_and_position"
    t.index ["revision_id", "slug"], name: "index_pages_on_revision_id_and_slug", unique: true
    t.index ["revision_id"], name: "index_pages_on_revision_id"
  end

  create_table "photos", force: :cascade do |t|
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
    t.index ["human_name", "created_at"], name: "index_photos_on_human_name_and_created_at"
    t.index ["human_name", "sha256"], name: "index_photos_on_human_name_and_sha256", unique: true
  end

  create_table "revision_messages", force: :cascade do |t|
    t.bigint "revision_id", null: false
    t.string "role", null: false
    t.text "content"
    t.json "tool_calls"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["revision_id", "created_at"], name: "index_revision_messages_on_revision_id_and_created_at"
  end

  create_table "revisions", force: :cascade do |t|
    t.string "state", default: "draft", null: false
    t.string "title"
    t.string "created_by"
    t.bigint "based_on_id"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state"], name: "index_revisions_on_state"
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "page_id", null: false
    t.integer "position", default: 0, null: false
    t.string "style", default: "plain", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "column_widths"
    t.bigint "revision_id", null: false
    t.index ["page_id", "position"], name: "index_sections_on_page_id_and_position"
    t.index ["page_id"], name: "index_sections_on_page_id"
    t.index ["revision_id"], name: "index_sections_on_revision_id"
  end

  create_table "templates", force: :cascade do |t|
    t.bigint "revision_id", null: false
    t.string "name", null: false
    t.text "source", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["revision_id", "name"], name: "index_templates_on_revision_id_and_name", unique: true
  end

  create_table "theme_assets", force: :cascade do |t|
    t.bigint "revision_id", null: false
    t.string "name", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["revision_id", "name"], name: "index_theme_assets_on_revision_id_and_name", unique: true
  end

  add_foreign_key "blocks", "sections"
  add_foreign_key "lectionary_readings", "lectionary_days"
  add_foreign_key "sections", "pages"
end
