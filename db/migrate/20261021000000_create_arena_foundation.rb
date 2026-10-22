class CreateArenaFoundation < ActiveRecord::Migration[7.1]
  def up
    create_table :arena_host_grants, id: :uuid do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.uuid :operator_reference, null: false
      t.datetime :granted_at, null: false
      t.datetime :revoked_at
      t.uuid :revocation_reference
      t.timestamps
    end
    add_index :arena_host_grants, :user_id, unique: true, where: "revoked_at IS NULL", name: "arena_one_active_host_grant"
    add_check_constraint :arena_host_grants, "(revoked_at IS NULL) = (revocation_reference IS NULL) AND (revoked_at IS NULL OR revoked_at >= granted_at)", name: "arena_grant_revocation"
    add_check_constraint :arena_host_grants, "user_id IS NOT NULL OR revoked_at IS NOT NULL", name: "arena_anonymous_grant_revoked"

    create_table :arena_sessions, id: :uuid do |t|
      t.references :host, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :title, null: false
      t.string :state, null: false, default: "draft"
      t.string :visibility, null: false, default: "private"
      t.string :resume_from
      t.integer :lock_version, null: false, default: 0
      t.bigint :event_sequence, null: false, default: 0
      t.datetime :ended_at
      t.timestamps
    end
    add_check_constraint :arena_sessions, "state::text IN ('draft','lobby_open','lobby_locked','live','paused','interrupted','completed','cancelled','expired')", name: "arena_session_state"
    add_check_constraint :arena_sessions, "visibility = 'private' AND length(btrim(title)) BETWEEN 1 AND 120 AND lock_version >= 0 AND event_sequence >= 0", name: "arena_session_values"
    add_check_constraint :arena_sessions, "host_id IS NOT NULL OR state::text IN ('completed','cancelled','expired')", name: "arena_removed_host_terminal"
    add_check_constraint :arena_sessions, "(state::text IN ('completed','cancelled','expired')) = (ended_at IS NOT NULL)", name: "arena_session_terminal_time"
    add_check_constraint :arena_sessions, "state <> 'interrupted' OR (resume_from IS NOT NULL AND resume_from::text IN ('live','paused'))", name: "arena_session_resume"

    create_table :arena_memberships, id: :uuid do |t|
      t.references :arena_session, type: :uuid, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :nickname, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :arena_memberships, [:arena_session_id, :user_id], unique: true, name: "arena_member_once_per_user"
    add_index :arena_memberships, [:arena_session_id, :id], unique: true, name: "arena_membership_session_identity"
    add_check_constraint :arena_memberships, "status::text IN ('active','left','removed') AND length(btrim(nickname)) BETWEEN 1 AND 40", name: "arena_membership_values"
    add_check_constraint :arena_memberships, "user_id IS NOT NULL OR (status = 'removed' AND nickname = 'Participante removido')", name: "arena_anonymous_membership"

    create_table :arena_question_snapshots, id: :uuid do |t|
      t.references :arena_session, type: :uuid, null: false, foreign_key: true
      t.string :payload_version, null: false
      t.string :payload_digest, null: false
      t.jsonb :payload, null: false
      t.datetime :created_at, null: false
    end
    add_index :arena_question_snapshots, [:arena_session_id, :id], unique: true, name: "arena_snapshot_session_identity"
    add_check_constraint :arena_question_snapshots, "payload_version = 'choice-v1' AND payload_digest ~ '^[0-9a-f]{64}$' AND jsonb_typeof(payload) = 'object'", name: "arena_snapshot_contract"

    create_table :arena_rounds, id: :uuid do |t|
      t.references :arena_session, type: :uuid, null: false, foreign_key: true
      t.uuid :arena_question_snapshot_id, null: false
      t.integer :position, null: false
      t.string :state, null: false, default: "queued"
      t.string :paused_from
      t.bigint :remaining_ms
      t.datetime :answer_open_at
      t.datetime :deadline_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :arena_rounds, [:arena_session_id, :position], unique: true, name: "arena_round_position"
    add_index :arena_rounds, [:arena_session_id, :id], unique: true, name: "arena_round_session_identity"
    add_index :arena_rounds, :arena_session_id, unique: true, where: "state::text IN ('preparing','ready','answering','paused')", name: "arena_one_open_round"
    add_foreign_key :arena_rounds, :arena_question_snapshots, column: [:arena_session_id, :arena_question_snapshot_id], primary_key: [:arena_session_id, :id], name: "arena_round_snapshot_same_session"
    add_check_constraint :arena_rounds, "state::text IN ('queued','preparing','ready','answering','closed','results','paused','void') AND position > 0 AND lock_version >= 0", name: "arena_round_values"
    add_check_constraint :arena_rounds, "(answer_open_at IS NULL AND deadline_at IS NULL) OR (answer_open_at IS NOT NULL AND deadline_at IS NOT NULL AND deadline_at > answer_open_at)", name: "arena_round_window"
    add_check_constraint :arena_rounds, "state <> 'answering' OR (answer_open_at IS NOT NULL AND deadline_at IS NOT NULL)", name: "arena_answering_has_window"
    add_check_constraint :arena_rounds, "state <> 'paused' OR (paused_from IS NOT NULL AND paused_from::text IN ('preparing','ready','answering') AND remaining_ms >= 0 AND remaining_ms IS NOT NULL)", name: "arena_round_pause"

    create_table :arena_answers, id: :uuid do |t|
      t.references :arena_session, type: :uuid, null: false, foreign_key: true
      t.uuid :arena_round_id, null: false
      t.uuid :arena_membership_id, null: false
      t.string :option_id, null: false
      t.uuid :idempotency_key, null: false
      t.datetime :accepted_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :arena_answers, [:arena_round_id, :arena_membership_id], unique: true, name: "arena_one_answer_per_round"
    add_index :arena_answers, [:arena_membership_id, :idempotency_key], unique: true, name: "arena_answer_idempotency"
    add_foreign_key :arena_answers, :arena_rounds, column: [:arena_session_id, :arena_round_id], primary_key: [:arena_session_id, :id], name: "arena_answer_round_same_session"
    add_foreign_key :arena_answers, :arena_memberships, column: [:arena_session_id, :arena_membership_id], primary_key: [:arena_session_id, :id], name: "arena_answer_member_same_session"
    add_check_constraint :arena_answers, "option_id ~ '^[A-Za-z0-9_-]{1,80}$'", name: "arena_answer_option_format"

    create_table :arena_events, id: :uuid do |t|
      t.references :arena_session, type: :uuid, null: false, foreign_key: true
      t.uuid :arena_round_id
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.bigint :sequence, null: false
      t.integer :session_version, null: false
      t.string :kind, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :arena_events, [:arena_session_id, :sequence], unique: true, name: "arena_event_sequence"
    add_foreign_key :arena_events, :arena_rounds, column: [:arena_session_id, :arena_round_id], primary_key: [:arena_session_id, :id], name: "arena_event_round_same_session"
    add_check_constraint :arena_events, "sequence > 0 AND session_version >= 0 AND jsonb_typeof(payload) = 'object'", name: "arena_event_values"
    add_check_constraint :arena_events, "kind::text IN ('session_created','session_state_changed','round_state_changed','answer_recorded','account_removed')", name: "arena_event_kind"

    execute <<~SQL
      CREATE FUNCTION arena_f1_immutable_history() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'Arena history is immutable' USING ERRCODE = '23514';
      END $$;
      CREATE TRIGGER arena_snapshot_immutable BEFORE UPDATE OR DELETE ON arena_question_snapshots
        FOR EACH ROW EXECUTE FUNCTION arena_f1_immutable_history();
      CREATE TRIGGER arena_answer_immutable BEFORE UPDATE OR DELETE ON arena_answers
        FOR EACH ROW EXECUTE FUNCTION arena_f1_immutable_history();

      CREATE FUNCTION arena_f1_event_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND NEW.actor_id IS NULL AND
          (to_jsonb(NEW) - 'actor_id') = (to_jsonb(OLD) - 'actor_id') THEN RETURN NEW; END IF;
        RAISE EXCEPTION 'Arena event is immutable' USING ERRCODE = '23514';
      END $$;
      CREATE TRIGGER arena_event_immutable BEFORE UPDATE OR DELETE ON arena_events
        FOR EACH ROW EXECUTE FUNCTION arena_f1_event_guard();

      CREATE FUNCTION arena_f1_grant_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'Grant history cannot be deleted' USING ERRCODE = '23514'; END IF;
        IF NEW.id <> OLD.id OR NEW.operator_reference <> OLD.operator_reference OR NEW.granted_at <> OLD.granted_at OR
          NEW.created_at <> OLD.created_at OR (NEW.user_id IS NOT NULL AND NEW.user_id IS DISTINCT FROM OLD.user_id) OR
          (OLD.revoked_at IS NOT NULL AND (NEW.revoked_at IS DISTINCT FROM OLD.revoked_at OR NEW.revocation_reference IS DISTINCT FROM OLD.revocation_reference)) THEN
          RAISE EXCEPTION 'Grant history cannot be rewritten' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_grant_history BEFORE UPDATE OR DELETE ON arena_host_grants
        FOR EACH ROW EXECUTE FUNCTION arena_f1_grant_guard();

      CREATE FUNCTION arena_f1_membership_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.id <> OLD.id OR NEW.arena_session_id <> OLD.arena_session_id OR
          (NEW.user_id IS NOT NULL AND NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
          RAISE EXCEPTION 'Membership identity is immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_membership_identity BEFORE UPDATE ON arena_memberships
        FOR EACH ROW EXECUTE FUNCTION arena_f1_membership_guard();

      CREATE FUNCTION arena_f1_session_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.id <> OLD.id OR (NEW.host_id IS NOT NULL AND NEW.host_id IS DISTINCT FROM OLD.host_id) OR
          NEW.event_sequence < OLD.event_sequence THEN
          RAISE EXCEPTION 'Session identity or sequence cannot be rewritten' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_session_identity BEFORE UPDATE ON arena_sessions
        FOR EACH ROW EXECUTE FUNCTION arena_f1_session_guard();

      CREATE FUNCTION arena_f1_round_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.id <> OLD.id OR NEW.arena_session_id <> OLD.arena_session_id OR
          NEW.arena_question_snapshot_id <> OLD.arena_question_snapshot_id OR NEW.position <> OLD.position THEN
          RAISE EXCEPTION 'Round identity is immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_round_identity BEFORE UPDATE ON arena_rounds
        FOR EACH ROW EXECUTE FUNCTION arena_f1_round_guard();

      CREATE FUNCTION arena_f1_anonymize_account() RETURNS trigger LANGUAGE plpgsql AS $$
      DECLARE room record; next_sequence bigint; next_version integer; terminal_state text; affected uuid[];
      BEGIN
        -- Same session lock order for removal and ordinary commands; no peer PII is copied.
        SELECT array_agg(id ORDER BY id) INTO affected FROM arena_sessions WHERE host_id = OLD.id OR id IN
          (SELECT arena_session_id FROM arena_memberships WHERE user_id = OLD.id);
        PERFORM id FROM arena_sessions WHERE id = ANY(affected) ORDER BY id FOR UPDATE;
        UPDATE arena_host_grants SET user_id = NULL, revoked_at = COALESCE(revoked_at, clock_timestamp()),
          revocation_reference = COALESCE(revocation_reference, gen_random_uuid()), updated_at = clock_timestamp() WHERE user_id = OLD.id;
        UPDATE arena_memberships SET user_id = NULL, nickname = 'Participante removido', status = 'removed', updated_at = clock_timestamp() WHERE user_id = OLD.id;
        FOR room IN SELECT * FROM arena_sessions WHERE id = ANY(affected) ORDER BY id LOOP
          IF room.host_id = OLD.id THEN
            terminal_state := CASE WHEN room.state IN ('completed','cancelled','expired') THEN room.state ELSE 'cancelled' END;
            UPDATE arena_rounds SET state = 'void', lock_version = lock_version + 1, updated_at = clock_timestamp()
              WHERE arena_session_id = room.id AND state NOT IN ('closed','results','void');
            UPDATE arena_sessions SET host_id = NULL, title = 'Sessão encerrada', state = terminal_state,
              ended_at = COALESCE(ended_at, clock_timestamp()), event_sequence = event_sequence + 1,
              lock_version = lock_version + 1, updated_at = clock_timestamp()
              WHERE id = room.id RETURNING event_sequence, lock_version INTO next_sequence, next_version;
          ELSE
            terminal_state := room.state;
            UPDATE arena_sessions SET event_sequence = event_sequence + 1, lock_version = lock_version + 1,
              updated_at = clock_timestamp() WHERE id = room.id RETURNING event_sequence, lock_version INTO next_sequence, next_version;
          END IF;
          INSERT INTO arena_events(id, arena_session_id, sequence, session_version, kind, payload, created_at)
            VALUES(gen_random_uuid(), room.id, next_sequence, next_version, 'account_removed', jsonb_build_object('state', terminal_state), clock_timestamp());
        END LOOP;
        RETURN OLD;
      END $$;
      CREATE TRIGGER arena_account_removal BEFORE DELETE ON users
        FOR EACH ROW EXECUTE FUNCTION arena_f1_anonymize_account();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Arena history and account anonymization require an explicitly reviewed rollback plan"
  end
end
