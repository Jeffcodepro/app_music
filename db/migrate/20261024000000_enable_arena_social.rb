class EnableArenaSocial < ActiveRecord::Migration[7.1]
  def up
    add_column :arena_sessions, :capacity, :integer, null: false, default: 30
    add_column :arena_sessions, :scoring_version, :string, null: false, default: "accuracy-1000-v1"
    add_check_constraint :arena_sessions, "capacity >= 1 AND capacity <= 30 AND scoring_version::text IN ('accuracy-1000-v1','speed-streak-v1')", name: "arena_social_configuration"
    remove_check_constraint :arena_sessions, name: "arena_session_values"
    add_check_constraint :arena_sessions, "visibility::text IN ('private','public') AND length(btrim(title)) BETWEEN 1 AND 120 AND lock_version >= 0 AND event_sequence >= 0", name: "arena_session_values"
    remove_check_constraint :arena_sessions, name: "arena_duration_values"
    add_check_constraint :arena_sessions, "duration_seconds IS NULL OR duration_seconds BETWEEN 10 AND 120", name: "arena_duration_values"
    add_index :arena_sessions, :created_at, where: "visibility = 'public' AND state = 'lobby_open'", name: "arena_public_lobbies"

    add_column :arena_memberships, :avatar_id, :string, null: false, default: "neutral"
    add_check_constraint :arena_memberships, "avatar_id::text IN ('neutral','fox','cat','owl','robot','penguin','octopus')", name: "arena_avatar_values"
    remove_check_constraint :arena_memberships, name: "arena_anonymous_membership"
    add_check_constraint :arena_memberships, "user_id IS NOT NULL OR (status = 'removed' AND nickname = 'Participante removido' AND avatar_id = 'neutral')", name: "arena_anonymous_membership"
    add_column :arena_answers, :response_elapsed_ms, :integer
    add_check_constraint :arena_answers, "response_elapsed_ms IS NULL OR response_elapsed_ms BETWEEN 0 AND 119999", name: "arena_answer_elapsed"

    execute <<~SQL
      CREATE FUNCTION arena_social_configuration_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.state <> 'draft' AND ROW(NEW.capacity,NEW.scoring_version,NEW.duration_seconds,NEW.visibility,NEW.experience,NEW.arena_content_version_id)
          IS DISTINCT FROM ROW(OLD.capacity,OLD.scoring_version,OLD.duration_seconds,OLD.visibility,OLD.experience,OLD.arena_content_version_id) THEN
          RAISE EXCEPTION 'Arena game configuration is immutable' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_social_configuration BEFORE UPDATE ON arena_sessions
        FOR EACH ROW EXECUTE FUNCTION arena_social_configuration_guard();

      CREATE FUNCTION arena_social_avatar_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.avatar_id IS DISTINCT FROM OLD.avatar_id AND NOT (NEW.user_id IS NULL AND NEW.avatar_id = 'neutral') THEN
          RAISE EXCEPTION 'Arena character is immutable' USING ERRCODE = '23514';
        END IF;
        IF OLD.status = 'removed' AND NEW.status <> 'removed' THEN
          RAISE EXCEPTION 'Removed membership cannot rejoin' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_social_avatar BEFORE UPDATE ON arena_memberships
        FOR EACH ROW EXECUTE FUNCTION arena_social_avatar_guard();

      CREATE FUNCTION arena_social_timing_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      DECLARE version text; duration integer;
      BEGIN
        SELECT scoring_version,duration_seconds INTO version,duration FROM arena_sessions WHERE id=NEW.arena_session_id;
        IF version = 'speed-streak-v1' AND (duration IS NULL OR duration <= 0 OR NEW.response_elapsed_ms IS NULL OR NEW.response_elapsed_ms >= duration * 1000) THEN
          RAISE EXCEPTION 'Arena speed scoring requires bounded server timing' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_social_timing BEFORE INSERT ON arena_answers
        FOR EACH ROW EXECUTE FUNCTION arena_social_timing_guard();

      CREATE FUNCTION arena_social_anonymize_account() RETURNS trigger LANGUAGE plpgsql AS $$
      DECLARE room record; next_sequence bigint; next_version integer; terminal_state text; affected uuid[];
      BEGIN
        SELECT array_agg(id ORDER BY id) INTO affected FROM arena_sessions WHERE host_id = OLD.id OR id IN
          (SELECT arena_session_id FROM arena_memberships WHERE user_id = OLD.id);
        PERFORM id FROM arena_sessions WHERE id = ANY(affected) ORDER BY id FOR UPDATE;
        UPDATE arena_host_grants SET user_id = NULL, revoked_at = COALESCE(revoked_at, clock_timestamp()),
          revocation_reference = COALESCE(revocation_reference, gen_random_uuid()), updated_at = clock_timestamp() WHERE user_id = OLD.id;
        UPDATE arena_memberships SET user_id = NULL, nickname = 'Participante removido', avatar_id = 'neutral', status = 'removed', updated_at = clock_timestamp() WHERE user_id = OLD.id;
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
      DROP TRIGGER arena_account_removal ON users;
      CREATE TRIGGER arena_account_removal BEFORE DELETE ON users
        FOR EACH ROW EXECUTE FUNCTION arena_social_anonymize_account();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve characters, scoring versions and accepted timing before rollback"
  end
end
