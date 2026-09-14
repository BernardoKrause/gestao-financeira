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

ActiveRecord::Schema[8.1].define(version: 2026_09_14_090100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.integer "muscle_group", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_exercises_on_user_id"
  end

  create_table "program_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "workout_program_id", null: false
    t.index ["workout_program_id"], name: "index_program_days_on_workout_program_id"
  end

  create_table "program_exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.integer "position", null: false
    t.bigint "program_day_id", null: false
    t.integer "target_duration_minutes"
    t.integer "target_reps"
    t.integer "target_sets"
    t.datetime "updated_at", null: false
    t.index ["exercise_id"], name: "index_program_exercises_on_exercise_id"
    t.index ["program_day_id"], name: "index_program_exercises_on_program_day_id"
  end

  create_table "recurring_entries", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_month", null: false
    t.string "description", null: false
    t.integer "installments"
    t.integer "kind", default: 0, null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_recurring_entries_on_category_id"
    t.index ["user_id"], name: "index_recurring_entries_on_user_id"
  end

  create_table "set_logs", force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.integer "position", null: false
    t.bigint "program_exercise_id", null: false
    t.integer "reps"
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 6, scale: 2
    t.bigint "workout_session_id", null: false
    t.index ["program_exercise_id"], name: "index_set_logs_on_program_exercise_id"
    t.index ["workout_session_id"], name: "index_set_logs_on_workout_session_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "initial_balance", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_settings_on_user_id", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description", null: false
    t.integer "kind", default: 0, null: false
    t.bigint "recurring_entry_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["recurring_entry_id"], name: "index_transactions_on_recurring_entry_id"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workout_programs", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_workout_programs_on_user_id"
  end

  create_table "workout_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "program_day_id", null: false
    t.datetime "started_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workout_program_id", null: false
    t.index ["program_day_id"], name: "index_workout_sessions_on_program_day_id"
    t.index ["user_id"], name: "index_workout_sessions_on_user_id"
    t.index ["workout_program_id"], name: "index_workout_sessions_on_workout_program_id"
  end

  add_foreign_key "categories", "users"
  add_foreign_key "exercises", "users"
  add_foreign_key "program_days", "workout_programs"
  add_foreign_key "program_exercises", "exercises"
  add_foreign_key "program_exercises", "program_days"
  add_foreign_key "recurring_entries", "categories"
  add_foreign_key "recurring_entries", "users"
  add_foreign_key "set_logs", "program_exercises"
  add_foreign_key "set_logs", "workout_sessions"
  add_foreign_key "settings", "users"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "recurring_entries"
  add_foreign_key "transactions", "users"
  add_foreign_key "workout_programs", "users"
  add_foreign_key "workout_sessions", "program_days"
  add_foreign_key "workout_sessions", "users"
  add_foreign_key "workout_sessions", "workout_programs"
end
