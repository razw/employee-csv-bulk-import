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

ActiveRecord::Schema[8.1].define(version: 2026_11_25_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_departments_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_departments_on_tenant_id"
  end

  create_table "employee_import_errors", force: :cascade do |t|
    t.bigint "employee_import_id", null: false
    t.integer "row_number", null: false
    t.string "column"
    t.string "message", null: false
    t.index ["employee_import_id", "row_number"], name: "idx_on_employee_import_id_row_number_8a2a3f874b"
  end

  create_table "employee_imports", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_rows"
    t.integer "imported_count", default: 0, null: false
    t.integer "error_count", default: 0, null: false
    t.string "failure_reason"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_employee_imports_on_requested_by_id"
    t.index ["tenant_id"], name: "index_employee_imports_on_tenant_id"
    t.index ["tenant_id"], name: "index_employee_imports_one_active_per_tenant", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying])::text[]))"
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "department_id", null: false
    t.string "employee_number", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["tenant_id", "email"], name: "index_employees_on_tenant_id_and_email", unique: true
    t.index ["tenant_id", "employee_number"], name: "index_employees_on_tenant_id_and_employee_number", unique: true
    t.index ["tenant_id"], name: "index_employees_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "departments", "tenants"
  add_foreign_key "employee_import_errors", "employee_imports", on_delete: :cascade
  add_foreign_key "employee_imports", "tenants"
  add_foreign_key "employee_imports", "users", column: "requested_by_id"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "tenants"
  add_foreign_key "users", "tenants"
end
