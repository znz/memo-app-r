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

ActiveRecord::Schema[8.1].define(version: 2026_09_26_084643) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "memos", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "content"
    t.inet "create_from", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "hostname"
    t.string "info"
    t.geography "lonlat", limit: {srid: 4326, type: "st_point", geographic: true}
    t.integer "price"
    t.string "tags", array: true
    t.datetime "updated_at", precision: nil, null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["created_at"], name: "index_memos_on_created_at"
    t.index ["lonlat"], name: "index_memos_on_lonlat", using: :gist
    t.index ["tags"], name: "index_memos_on_tags", using: :gin
    t.index ["user_id"], name: "index_memos_on_user_id"
  end

  create_table "reminder_tags", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "reminder_id", null: false
    t.uuid "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["reminder_id", "tag_id"], name: "index_reminder_tags_on_reminder_id_and_tag_id", unique: true
    t.index ["tag_id"], name: "index_reminder_tags_on_tag_id"
  end

  create_table "reminders", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.integer "completed_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "due_at"
    t.boolean "enabled", default: true, null: false
    t.datetime "last_completed_at"
    t.geography "lonlat", limit: {srid: 4326, type: "st_point", geographic: true}
    t.string "memo_tags", default: [], null: false, array: true
    t.text "memo_template"
    t.string "name", null: false
    t.integer "radius_m", default: 200, null: false
    t.jsonb "recurrence", default: {"type" => "none"}, null: false
    t.datetime "repeat_until"
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["lonlat"], name: "index_reminders_on_lonlat", using: :gist
    t.index ["user_id"], name: "index_reminders_on_user_id"
  end

  create_table "tags", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "color", default: "secondary", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at", precision: nil
    t.inet "last_sign_in_ip"
    t.datetime "locked_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "reminder_tags", "reminders", on_delete: :cascade
  add_foreign_key "reminder_tags", "tags", on_delete: :cascade
  add_foreign_key "reminders", "users"
  add_foreign_key "tags", "users"
end
