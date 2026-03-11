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

ActiveRecord::Schema[8.1].define(version: 2026_03_11_130406) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message"
    t.bigint "project_id", null: false
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "work_process_id", null: false
    t.index ["project_id"], name: "index_notifications_on_project_id"
    t.index ["work_process_id"], name: "index_notifications_on_work_process_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "address"
    t.string "client_name"
    t.string "color"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.text "memo"
    t.string "project_name"
    t.string "project_type"
    t.date "start_date"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "work_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "work_date"
    t.bigint "work_process_id", null: false
    t.index ["work_process_id"], name: "index_work_days_on_work_process_id"
  end

  create_table "work_processes", force: :cascade do |t|
    t.string "contractor_name"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.integer "labor_cost"
    t.integer "material_cost"
    t.text "memo"
    t.integer "position"
    t.string "process_name"
    t.bigint "project_id", null: false
    t.date "start_date"
    t.string "status"
    t.datetime "updated_at", null: false
    t.string "vendor_name"
    t.index ["project_id"], name: "index_work_processes_on_project_id"
  end

  add_foreign_key "notifications", "projects"
  add_foreign_key "notifications", "work_processes"
  add_foreign_key "work_days", "work_processes"
  add_foreign_key "work_processes", "projects"
end
