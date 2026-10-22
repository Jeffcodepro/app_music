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

ActiveRecord::Schema[7.1].define(version: 2026_10_28_000000) do
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

  create_table "arena_answers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "arena_session_id", null: false
    t.uuid "arena_round_id", null: false
    t.uuid "arena_membership_id", null: false
    t.string "option_id", null: false
    t.uuid "idempotency_key", null: false
    t.datetime "accepted_at", null: false
    t.datetime "created_at", null: false
    t.integer "response_elapsed_ms"
    t.index ["arena_membership_id", "idempotency_key"], name: "arena_answer_idempotency", unique: true
    t.index ["arena_round_id", "arena_membership_id"], name: "arena_one_answer_per_round", unique: true
    t.index ["arena_session_id"], name: "index_arena_answers_on_arena_session_id"
    t.check_constraint "option_id::text ~ '^[A-Za-z0-9_-]{1,80}$'::text", name: "arena_answer_option_format"
    t.check_constraint "response_elapsed_ms IS NULL OR response_elapsed_ms >= 0 AND response_elapsed_ms <= 119999", name: "arena_answer_elapsed"
  end

  create_table "arena_content_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.integer "revision", null: false
    t.string "title", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "body", null: false
    t.string "content_digest", null: false
    t.string "source_digest", null: false
    t.uuid "reviewer_reference"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code", "revision"], name: "arena_content_revision", unique: true
    t.check_constraint "(reviewer_reference IS NULL) = (reviewed_at IS NULL) AND (status::text <> 'published'::text OR reviewer_reference IS NOT NULL)", name: "arena_content_review"
    t.check_constraint "revision > 0 AND (status::text = ANY (ARRAY['draft'::text, 'technical_preview'::text, 'published'::text, 'archived'::text])) AND jsonb_typeof(body) = 'object'::text AND content_digest::text ~ '^[0-9a-f]{64}$'::text AND source_digest::text ~ '^[0-9a-f]{64}$'::text", name: "arena_content_values"
  end

  create_table "arena_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "arena_session_id", null: false
    t.uuid "arena_round_id"
    t.bigint "actor_id"
    t.bigint "sequence", null: false
    t.integer "session_version", null: false
    t.string "kind", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_arena_events_on_actor_id"
    t.index ["arena_session_id", "sequence"], name: "arena_event_sequence", unique: true
    t.index ["arena_session_id"], name: "index_arena_events_on_arena_session_id"
    t.check_constraint "kind::text = ANY (ARRAY['session_created'::text, 'session_state_changed'::text, 'round_state_changed'::text, 'answer_recorded'::text, 'account_removed'::text])", name: "arena_event_kind"
    t.check_constraint "sequence > 0 AND session_version >= 0 AND jsonb_typeof(payload) = 'object'::text", name: "arena_event_values"
  end

  create_table "arena_host_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "user_id"
    t.uuid "operator_reference", null: false
    t.datetime "granted_at", null: false
    t.datetime "revoked_at"
    t.uuid "revocation_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "arena_one_active_host_grant", unique: true, where: "(revoked_at IS NULL)"
    t.index ["user_id"], name: "index_arena_host_grants_on_user_id"
    t.check_constraint "(revoked_at IS NULL) = (revocation_reference IS NULL) AND (revoked_at IS NULL OR revoked_at >= granted_at)", name: "arena_grant_revocation"
    t.check_constraint "user_id IS NOT NULL OR revoked_at IS NOT NULL", name: "arena_anonymous_grant_revoked"
  end

  create_table "arena_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "arena_session_id", null: false
    t.bigint "user_id"
    t.string "nickname", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "avatar_id", default: "neutral", null: false
    t.datetime "audio_ready_at"
    t.datetime "audio_excluded_at"
    t.index ["arena_session_id", "id"], name: "arena_membership_session_identity", unique: true
    t.index ["arena_session_id", "user_id"], name: "arena_member_once_per_user", unique: true
    t.index ["arena_session_id"], name: "index_arena_memberships_on_arena_session_id"
    t.index ["user_id"], name: "index_arena_memberships_on_user_id"
    t.check_constraint "(status::text = ANY (ARRAY['active'::text, 'left'::text, 'removed'::text])) AND length(btrim(nickname::text)) >= 1 AND length(btrim(nickname::text)) <= 40", name: "arena_membership_values"
    t.check_constraint "audio_excluded_at IS NULL OR status::text = 'removed'::text AND audio_ready_at IS NULL", name: "arena_audio_exclusion"
    t.check_constraint "avatar_id::text = ANY (ARRAY['neutral'::text, 'fox'::text, 'cat'::text, 'owl'::text, 'robot'::text, 'penguin'::text, 'octopus'::text, 'rabbit'::text, 'dog'::text, 'bear'::text, 'panda'::text, 'frog'::text, 'dragon'::text])", name: "arena_avatar_values"
    t.check_constraint "user_id IS NOT NULL OR status::text = 'removed'::text AND nickname::text = 'Participante removido'::text AND avatar_id::text = 'neutral'::text", name: "arena_anonymous_membership"
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

  create_table "arena_question_snapshots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "arena_session_id", null: false
    t.string "payload_version", null: false
    t.string "payload_digest", null: false
    t.jsonb "payload", null: false
    t.datetime "created_at", null: false
    t.uuid "arena_content_version_id"
    t.index ["arena_content_version_id"], name: "index_arena_question_snapshots_on_arena_content_version_id"
    t.index ["arena_session_id", "id"], name: "arena_snapshot_session_identity", unique: true
    t.index ["arena_session_id"], name: "index_arena_question_snapshots_on_arena_session_id"
    t.check_constraint "(payload_version::text = ANY (ARRAY['choice-v1'::text, 'reading-note-v1'::text, 'reading-visual-v2'::text, 'music-choice-v3'::text])) AND payload_digest::text ~ '^[0-9a-f]{64}$'::text AND jsonb_typeof(payload) = 'object'::text AND (payload_version::text = 'choice-v1'::text OR arena_content_version_id IS NOT NULL)", name: "arena_snapshot_contract"
  end

  create_table "arena_rate_windows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key_digest", null: false
    t.datetime "window_at", null: false
    t.integer "attempts", null: false
    t.datetime "expires_at", null: false
    t.index ["expires_at"], name: "index_arena_rate_windows_on_expires_at"
    t.index ["key_digest", "window_at"], name: "arena_rate_window_identity", unique: true
    t.check_constraint "key_digest::text ~ '^[0-9a-f]{64}$'::text AND attempts > 0 AND expires_at > window_at", name: "arena_rate_values"
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

  create_table "arena_rounds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "arena_session_id", null: false
    t.uuid "arena_question_snapshot_id", null: false
    t.integer "position", null: false
    t.string "state", default: "queued", null: false
    t.string "paused_from"
    t.bigint "remaining_ms"
    t.datetime "answer_open_at"
    t.datetime "deadline_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "advance_at"
    t.integer "playback_generation", default: 1, null: false
    t.jsonb "playbacks", default: {}, null: false
    t.datetime "listening_started_at"
    t.jsonb "listening_progress", default: {}, null: false
    t.index ["arena_session_id", "id"], name: "arena_round_session_identity", unique: true
    t.index ["arena_session_id", "position"], name: "arena_round_position", unique: true
    t.index ["arena_session_id"], name: "arena_one_open_round", unique: true, where: "((state)::text = ANY (ARRAY['preparing'::text, 'ready'::text, 'answering'::text, 'paused'::text]))"
    t.index ["arena_session_id"], name: "index_arena_rounds_on_arena_session_id"
    t.check_constraint "(state::text = ANY (ARRAY['queued'::text, 'preparing'::text, 'ready'::text, 'answering'::text, 'closed'::text, 'results'::text, 'paused'::text, 'void'::text])) AND \"position\" > 0 AND lock_version >= 0", name: "arena_round_values"
    t.check_constraint "advance_at IS NULL OR state::text = 'results'::text", name: "arena_result_advance"
    t.check_constraint "answer_open_at IS NULL AND deadline_at IS NULL OR answer_open_at IS NOT NULL AND deadline_at IS NOT NULL AND deadline_at > answer_open_at", name: "arena_round_window"
    t.check_constraint "jsonb_typeof(listening_progress) = 'object'::text", name: "arena_listening_progress"
    t.check_constraint "playback_generation >= 1 AND jsonb_typeof(playbacks) = 'object'::text", name: "arena_playback_values"
    t.check_constraint "state::text <> 'answering'::text OR answer_open_at IS NOT NULL AND deadline_at IS NOT NULL", name: "arena_answering_has_window"
    t.check_constraint "state::text <> 'paused'::text OR paused_from IS NOT NULL AND (paused_from::text = ANY (ARRAY['preparing'::text, 'ready'::text, 'answering'::text])) AND remaining_ms >= 0 AND remaining_ms IS NOT NULL", name: "arena_round_pause"
  end

  create_table "arena_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "host_id"
    t.string "title", null: false
    t.string "state", default: "draft", null: false
    t.string "visibility", default: "private", null: false
    t.string "resume_from"
    t.integer "lock_version", default: 0, null: false
    t.bigint "event_sequence", default: 0, null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "arena_content_version_id"
    t.string "invite_digest"
    t.text "invite_ciphertext"
    t.datetime "invite_expires_at"
    t.integer "duration_seconds"
    t.string "experience", default: "facilitated", null: false
    t.uuid "rematch_session_id"
    t.integer "capacity", default: 40, null: false
    t.string "scoring_version", default: "accuracy-1000-v1", null: false
    t.string "presentation_mode", default: "legacy", null: false
    t.string "listening_policy", default: "manual-v1", null: false
    t.integer "listening_repetitions", default: 3, null: false
    t.uuid "audio_check_id"
    t.datetime "audio_check_started_at"
    t.datetime "audio_check_deadline_at"
    t.datetime "host_audio_ready_at"
    t.index ["arena_content_version_id"], name: "index_arena_sessions_on_arena_content_version_id"
    t.index ["created_at"], name: "arena_public_lobbies", where: "(((visibility)::text = 'public'::text) AND ((state)::text = 'lobby_open'::text))"
    t.index ["host_id"], name: "index_arena_sessions_on_host_id"
    t.index ["id", "arena_content_version_id"], name: "arena_session_content_identity", unique: true
    t.index ["invite_digest"], name: "arena_unique_invite", unique: true, where: "(invite_digest IS NOT NULL)"
    t.index ["rematch_session_id"], name: "index_arena_sessions_on_rematch_session_id", unique: true
    t.check_constraint "(listening_policy::text = ANY (ARRAY['manual-v1'::text, 'sequence-v1'::text])) AND listening_repetitions >= 1 AND listening_repetitions <= 5", name: "arena_listening_configuration"
    t.check_constraint "(presentation_mode::text = ANY (ARRAY['legacy'::text, 'individual'::text, 'presenter'::text])) AND (presentation_mode::text <> 'presenter'::text OR experience::text = 'facilitated'::text) AND (presentation_mode::text <> 'individual'::text OR experience::text = 'party'::text)", name: "arena_presentation_values"
    t.check_constraint "(state::text = ANY (ARRAY['completed'::text, 'cancelled'::text, 'expired'::text])) = (ended_at IS NOT NULL)", name: "arena_session_terminal_time"
    t.check_constraint "(visibility::text = ANY (ARRAY['private'::text, 'public'::text])) AND length(btrim(title::text)) >= 1 AND length(btrim(title::text)) <= 120 AND lock_version >= 0 AND event_sequence >= 0", name: "arena_session_values"
    t.check_constraint "arena_content_version_id IS NULL OR duration_seconds IS NOT NULL AND invite_digest IS NOT NULL AND invite_ciphertext IS NOT NULL AND invite_expires_at IS NOT NULL", name: "arena_pilot_configuration"
    t.check_constraint "audio_check_id IS NULL AND audio_check_started_at IS NULL AND audio_check_deadline_at IS NULL AND host_audio_ready_at IS NULL OR audio_check_id IS NOT NULL AND audio_check_started_at IS NOT NULL AND audio_check_deadline_at IS NOT NULL AND audio_check_deadline_at = (audio_check_started_at + 'PT45S'::interval) AND (host_audio_ready_at IS NULL OR host_audio_ready_at >= audio_check_started_at AND host_audio_ready_at < audio_check_deadline_at)", name: "arena_audio_check_timing"
    t.check_constraint "capacity >= 1 AND capacity <= 40 AND (scoring_version::text = ANY (ARRAY['accuracy-1000-v1'::text, 'speed-streak-v1'::text]))", name: "arena_social_configuration"
    t.check_constraint "duration_seconds IS NULL OR duration_seconds >= 10 AND duration_seconds <= 120", name: "arena_duration_values"
    t.check_constraint "experience::text = ANY (ARRAY['facilitated'::text, 'party'::text])", name: "arena_experience_values"
    t.check_constraint "host_id IS NOT NULL OR (state::text = ANY (ARRAY['completed'::text, 'cancelled'::text, 'expired'::text]))", name: "arena_removed_host_terminal"
    t.check_constraint "invite_digest IS NULL AND invite_ciphertext IS NULL AND invite_expires_at IS NULL OR invite_digest IS NOT NULL AND invite_digest::text ~ '^[0-9a-f]{64}$'::text AND invite_ciphertext IS NOT NULL AND invite_expires_at IS NOT NULL AND invite_expires_at > created_at", name: "arena_invite_values"
    t.check_constraint "rematch_session_id IS NULL OR rematch_session_id <> id AND state::text = 'completed'::text", name: "arena_rematch_completed"
    t.check_constraint "state::text <> 'interrupted'::text OR resume_from IS NOT NULL AND (resume_from::text = ANY (ARRAY['live'::text, 'paused'::text]))", name: "arena_session_resume"
    t.check_constraint "state::text = ANY (ARRAY['draft'::text, 'lobby_open'::text, 'lobby_locked'::text, 'live'::text, 'paused'::text, 'interrupted'::text, 'completed'::text, 'cancelled'::text, 'expired'::text])", name: "arena_session_state"
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
  add_foreign_key "arena_answers", "arena_memberships", column: ["arena_session_id", "arena_membership_id"], primary_key: ["arena_session_id", "id"], name: "arena_answer_member_same_session"
  add_foreign_key "arena_answers", "arena_rounds", column: ["arena_session_id", "arena_round_id"], primary_key: ["arena_session_id", "id"], name: "arena_answer_round_same_session"
  add_foreign_key "arena_answers", "arena_sessions"
  add_foreign_key "arena_events", "arena_rounds", column: ["arena_session_id", "arena_round_id"], primary_key: ["arena_session_id", "id"], name: "arena_event_round_same_session"
  add_foreign_key "arena_events", "arena_sessions"
  add_foreign_key "arena_events", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "arena_host_grants", "users", on_delete: :nullify
  add_foreign_key "arena_memberships", "arena_sessions"
  add_foreign_key "arena_memberships", "users", on_delete: :nullify
  add_foreign_key "arena_participants", "arena_rooms"
  add_foreign_key "arena_participants", "users"
  add_foreign_key "arena_question_snapshots", "arena_content_versions"
  add_foreign_key "arena_question_snapshots", "arena_sessions"
  add_foreign_key "arena_question_snapshots", "arena_sessions", column: ["arena_session_id", "arena_content_version_id"], primary_key: ["id", "arena_content_version_id"], name: "arena_snapshot_content_same_session"
  add_foreign_key "arena_responses", "arena_participants"
  add_foreign_key "arena_responses", "arena_round_questions"
  add_foreign_key "arena_rooms", "users", column: "host_id"
  add_foreign_key "arena_round_questions", "arena_rooms"
  add_foreign_key "arena_rounds", "arena_question_snapshots", column: ["arena_session_id", "arena_question_snapshot_id"], primary_key: ["arena_session_id", "id"], name: "arena_round_snapshot_same_session"
  add_foreign_key "arena_rounds", "arena_sessions"
  add_foreign_key "arena_sessions", "arena_content_versions"
  add_foreign_key "arena_sessions", "arena_sessions", column: "rematch_session_id"
  add_foreign_key "arena_sessions", "users", column: "host_id", on_delete: :nullify
  add_foreign_key "daily_visits", "users"
  add_foreign_key "exercise_assignments", "users"
  add_foreign_key "exercise_attempts", "exercise_assignments"
  add_foreign_key "playground_attempts", "users"
  add_foreign_key "study_activities", "exercise_assignments"
  add_foreign_key "study_activities", "users"
end
