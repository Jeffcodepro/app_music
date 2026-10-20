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

ActiveRecord::Schema[7.1].define(version: 2026_10_20_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "arena_participants", force: :cascade do |t|
    t.bigint "arena_room_id", null: false
    t.bigint "user_id", null: false
    t.string "nickname", null: false
    t.string "role", default: "player", null: false
    t.integer "points", default: 0, null: false
    t.integer "correct_answers", default: 0, null: false
    t.integer "answered_questions", default: 0, null: false
    t.integer "total_response_time_ms", default: 0, null: false
    t.datetime "joined_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arena_room_id", "user_id"], name: "index_arena_participants_on_arena_room_id_and_user_id", unique: true
    t.index ["arena_room_id"], name: "index_arena_participants_on_arena_room_id"
    t.index ["user_id"], name: "index_arena_participants_on_user_id"
  end

  create_table "arena_responses", force: :cascade do |t|
    t.bigint "arena_round_question_id", null: false
    t.bigint "arena_participant_id", null: false
    t.string "slot_key", null: false
    t.string "option_id", null: false
    t.boolean "correct", default: false, null: false
    t.integer "points_awarded", default: 0, null: false
    t.integer "response_time_ms", default: 0, null: false
    t.datetime "answered_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arena_participant_id"], name: "index_arena_responses_on_arena_participant_id"
    t.index ["arena_round_question_id", "arena_participant_id"], name: "index_arena_responses_on_question_and_participant", unique: true
    t.index ["arena_round_question_id"], name: "index_arena_responses_on_arena_round_question_id"
  end

  create_table "arena_rooms", force: :cascade do |t|
    t.bigint "host_id", null: false
    t.string "title", null: false
    t.string "room_code", null: false
    t.string "theme", null: false
    t.string "question_kind", null: false
    t.integer "question_count", null: false
    t.integer "question_duration_seconds", null: false
    t.string "difficulty", null: false
    t.string "question_source", default: "playgrounds", null: false
    t.string "advance_mode", null: false
    t.string "state", default: "lobby_open", null: false
    t.integer "current_question_position", default: 0, null: false
    t.datetime "current_round_started_at"
    t.datetime "round_results_started_at"
    t.datetime "lobby_closed_at"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "private", null: false
    t.index ["host_id"], name: "index_arena_rooms_on_host_id"
    t.index ["room_code"], name: "index_arena_rooms_on_room_code", unique: true
  end

  create_table "arena_round_questions", force: :cascade do |t|
    t.bigint "arena_room_id", null: false
    t.integer "position", null: false
    t.string "theme", null: false
    t.string "prompt_kind", null: false
    t.string "source_kind", null: false
    t.text "question_text", null: false
    t.string "correct_slot_key", null: false
    t.jsonb "content_data", default: {}, null: false
    t.jsonb "answer_slots", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arena_room_id", "position"], name: "index_arena_round_questions_on_room_and_position", unique: true
    t.index ["arena_room_id"], name: "index_arena_round_questions_on_arena_room_id"
  end

  create_table "daily_visits", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "visited_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "visited_on"], name: "index_daily_visits_on_user_id_and_visited_on", unique: true
    t.index ["user_id"], name: "index_daily_visits_on_user_id"
  end

  create_table "exercise_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.uuid "public_id", null: false
    t.uuid "answer_token", null: false
    t.string "area", null: false
    t.string "rules_version", null: false
    t.jsonb "exercise_payload", null: false
    t.string "content_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_exercise_assignments_on_public_id", unique: true
    t.index ["user_id"], name: "index_exercise_assignments_on_user_id"
    t.check_constraint "area::text = ANY (ARRAY['leitura'::character varying, 'percepcao'::character varying, 'ritmica'::character varying, 'harmonia'::character varying]::text[])", name: "exercise_assignment_area"
  end

  create_table "exercise_attempts", force: :cascade do |t|
    t.bigint "exercise_assignment_id", null: false
    t.uuid "attempt_token", null: false
    t.string "selected_option_id", null: false
    t.boolean "correct", null: false
    t.integer "xp_earned", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_assignment_id", "attempt_token"], name: "unique_exercise_attempt_token", unique: true
    t.index ["exercise_assignment_id"], name: "index_exercise_attempts_on_exercise_assignment_id"
    t.check_constraint "xp_earned >= 0 AND xp_earned <= 20", name: "exercise_attempt_credit_bounds"
  end

  create_table "playground_attempts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "activity", null: false
    t.string "area", null: false
    t.boolean "correct", null: false
    t.date "occurred_on", null: false
    t.datetime "answered_at", null: false
    t.integer "response_time_ms"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "activity", "occurred_on"], name: "idx_on_user_id_activity_occurred_on_d975e5f56a"
    t.index ["user_id", "answered_at"], name: "index_playground_attempts_on_user_id_and_answered_at"
    t.index ["user_id", "area", "occurred_on"], name: "index_playground_attempts_on_user_id_and_area_and_occurred_on"
    t.index ["user_id"], name: "index_playground_attempts_on_user_id"
  end

  create_table "study_activities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "area", null: false
    t.integer "xp_earned", default: 0, null: false
    t.integer "minutes_practiced", default: 0, null: false
    t.date "occurred_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "correct"
    t.string "source", default: "legacy", null: false
    t.bigint "exercise_assignment_id"
    t.index ["exercise_assignment_id"], name: "index_study_activities_on_exercise_assignment_id", unique: true
    t.index ["user_id", "area", "occurred_on"], name: "index_study_activities_on_user_id_and_area_and_occurred_on"
    t.index ["user_id", "occurred_on"], name: "index_study_activities_on_user_id_and_occurred_on"
    t.index ["user_id", "source", "occurred_on"], name: "index_study_activities_on_user_id_and_source_and_occurred_on"
    t.index ["user_id"], name: "index_study_activities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "full_name"
    t.string "phone"
    t.string "age_range"
    t.string "primary_instrument"
    t.string "secondary_instrument"
    t.string "musical_level"
    t.string "study_goal"
    t.integer "weekly_study_minutes"
    t.string "learning_mode"
    t.string "city"
    t.string "state"
    t.string "plan"
    t.boolean "accepted_terms"
    t.string "provider"
    t.string "uid"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "arena_participants", "arena_rooms"
  add_foreign_key "arena_participants", "users"
  add_foreign_key "arena_responses", "arena_participants"
  add_foreign_key "arena_responses", "arena_round_questions"
  add_foreign_key "arena_rooms", "users", column: "host_id"
  add_foreign_key "arena_round_questions", "arena_rooms"
  add_foreign_key "daily_visits", "users"
  add_foreign_key "exercise_assignments", "users"
  add_foreign_key "exercise_attempts", "exercise_assignments"
  add_foreign_key "playground_attempts", "users"
  add_foreign_key "study_activities", "exercise_assignments"
  add_foreign_key "study_activities", "users"
end
