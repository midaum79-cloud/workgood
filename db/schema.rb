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

ActiveRecord::Schema[8.1].define(version: 2026_03_14_120936) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.string "address"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "manager_name"
    t.text "memo"
    t.string "phone"
    t.datetime "updated_at", null: false
  end

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

  create_table "payments", force: :cascade do |t|
    t.integer "billed_amount"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.date "due_date"
    t.text "memo"
    t.date "paid_date"
    t.string "payment_type"
    t.integer "received_amount"
    t.integer "remaining_amount"
    t.bigint "site_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_payments_on_company_id"
    t.index ["site_id"], name: "index_payments_on_site_id"
  end

  create_table "process_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_default"
    t.string "name"
    t.integer "position"
    t.string "project_type"
    t.datetime "updated_at", null: false
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
    t.bigint "user_id"
  end

  create_table "site_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "labor_cost"
    t.text "memo"
    t.string "role"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["site_id"], name: "index_site_members_on_site_id"
    t.index ["user_id"], name: "index_site_members_on_user_id"
  end

  create_table "site_photos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image_type"
    t.text "memo"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_site_photos_on_site_id"
  end

  create_table "sites", force: :cascade do |t|
    t.integer "actual_cost"
    t.string "address"
    t.integer "billed_amount"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "expected_cost"
    t.text "memo"
    t.string "payment_status"
    t.string "process_type"
    t.integer "received_amount"
    t.string "site_name"
    t.string "site_status"
    t.integer "unpaid_amount"
    t.datetime "updated_at", null: false
    t.date "work_date"
    t.text "work_detail"
    t.string "work_summary"
    t.integer "worker_count"
    t.index ["company_id"], name: "index_sites_on_company_id"
  end

  create_table "subscription_payments", force: :cascade do |t|
    t.integer "amount"
    t.string "billing_key"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "imp_uid"
    t.string "merchant_uid"
    t.datetime "paid_at"
    t.string "plan"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_subscription_payments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "ai_imports_count"
    t.string "billing_key"
    t.datetime "billing_started_at"
    t.datetime "created_at", null: false
    t.string "customer_uid"
    t.string "email"
    t.boolean "evening_alert_enabled"
    t.string "evening_alert_time"
    t.boolean "is_active"
    t.text "memo"
    t.string "name"
    t.string "password_digest"
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token"
    t.string "phone"
    t.string "provider"
    t.string "role"
    t.datetime "subscription_expires_at"
    t.string "subscription_plan"
    t.string "team_name"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "vendors", force: :cascade do |t|
    t.string "contact_name"
    t.datetime "created_at", null: false
    t.text "memo"
    t.string "name"
    t.string "phone"
    t.string "specialty"
    t.datetime "updated_at", null: false
  end

  create_table "web_push_subscriptions", force: :cascade do |t|
    t.string "auth"
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "p256dh"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_web_push_subscriptions_on_user_id"
  end

  create_table "work_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "work_date"
    t.bigint "work_process_id", null: false
    t.index ["work_process_id"], name: "index_work_days_on_work_process_id"
  end

  create_table "work_processes", force: :cascade do |t|
    t.integer "budget"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "notifications", "projects"
  add_foreign_key "notifications", "work_processes"
  add_foreign_key "payments", "companies"
  add_foreign_key "payments", "sites"
  add_foreign_key "site_members", "sites"
  add_foreign_key "site_members", "users"
  add_foreign_key "site_photos", "sites"
  add_foreign_key "sites", "companies"
  add_foreign_key "subscription_payments", "users"
  add_foreign_key "web_push_subscriptions", "users"
  add_foreign_key "work_days", "work_processes"
  add_foreign_key "work_processes", "projects"
end
