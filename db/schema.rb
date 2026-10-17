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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_190923) do
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
    t.integer "asset_version"
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

  create_table "data_sources", force: :cascade do |t|
    t.bigint "revision_id", null: false
    t.string "name", null: false
    t.json "urls", default: [], null: false
    t.integer "refresh_minutes", default: 60, null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["revision_id", "name"], name: "index_data_sources_on_revision_id_and_name", unique: true
    t.index ["revision_id"], name: "index_data_sources_on_revision_id"
  end

  create_table "fetched_pages", force: :cascade do |t|
    t.string "key", null: false
    t.text "url", null: false
    t.text "body"
    t.string "content_type"
    t.integer "status"
    t.text "error"
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_fetched_pages_on_key", unique: true
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
    t.integer "hero_asset_version"
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
    t.integer "version", null: false
    t.index ["human_name", "created_at"], name: "index_photos_on_human_name_and_created_at"
    t.index ["human_name", "sha256"], name: "index_photos_on_human_name_and_sha256", unique: true
    t.index ["human_name", "version"], name: "index_photos_on_human_name_and_version", unique: true
  end

  create_table "promises", force: :cascade do |t|
    t.string "summary", null: false
    t.text "intent", null: false
    t.text "script", null: false
    t.string "page_slug"
    t.string "created_by"
    t.integer "introduced_in"
    t.text "proof"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "revision_messages", force: :cascade do |t|
    t.bigint "revision_id", null: false
    t.string "role", null: false
    t.text "content"
    t.json "tool_calls"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "done", null: false
    t.json "progress"
    t.json "usage"
    t.json "touched"
    t.index ["revision_id", "created_at"], name: "index_revision_messages_on_revision_id_and_created_at"
    t.index ["revision_id", "state"], name: "index_revision_messages_on_revision_id_and_state"
  end

  create_table "revision_promises", force: :cascade do |t|
    t.bigint "revision_id", null: false
    t.bigint "promise_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["promise_id"], name: "index_revision_promises_on_promise_id"
    t.index ["revision_id", "promise_id"], name: "index_revision_promises_on_revision_id_and_promise_id", unique: true
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

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
  add_foreign_key "data_sources", "revisions"
  add_foreign_key "lectionary_readings", "lectionary_days"
  add_foreign_key "sections", "pages"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
