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

ActiveRecord::Schema[8.0].define(version: 2026_10_27_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "policies", force: :cascade do |t|
    t.bigint "quote_id", null: false
    t.string "policy_number", null: false
    t.string "idempotency_key", null: false
    t.bigint "premium_cents", null: false
    t.date "effective_on", null: false
    t.date "expires_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "active", null: false
    t.date "cancelled_on"
    t.bigint "refund_cents"
    t.index ["idempotency_key"], name: "index_policies_on_idempotency_key", unique: true
    t.index ["policy_number"], name: "index_policies_on_policy_number", unique: true
    t.index ["quote_id"], name: "index_policies_on_quote_id", unique: true
    t.check_constraint "(status::text = 'cancelled'::text) = (cancelled_on IS NOT NULL AND refund_cents IS NOT NULL)", name: "policies_cancellation_check"
    t.check_constraint "refund_cents >= 0 AND refund_cents <= premium_cents", name: "policies_refund_range_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'cancelled'::character varying]::text[])", name: "policies_status_check"
  end

  create_table "quotes", force: :cascade do |t|
    t.string "state", limit: 2, null: false
    t.string "street_address", null: false
    t.string "zip", null: false
    t.integer "year_built", null: false
    t.integer "roof_age_years", null: false
    t.bigint "dwelling_coverage_cents", null: false
    t.bigint "premium_cents", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'bound'::character varying, 'expired'::character varying]::text[])", name: "quotes_status_check"
  end

  add_foreign_key "policies", "quotes"
end
