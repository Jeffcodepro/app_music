class EnableArenaEncore < ActiveRecord::Migration[7.1]
  def up
    remove_check_constraint :arena_sessions, name: "arena_social_configuration"
    add_check_constraint :arena_sessions, "capacity >= 1 AND capacity <= 40 AND scoring_version::text IN ('accuracy-1000-v1','speed-streak-v1')", name: "arena_social_configuration"
    change_column_default :arena_sessions, :capacity, from: 30, to: 40
    add_column :arena_sessions, :presentation_mode, :string, null: false, default: "legacy"
    add_check_constraint :arena_sessions, "presentation_mode::text IN ('legacy','individual','presenter') AND (presentation_mode <> 'presenter' OR experience = 'facilitated') AND (presentation_mode <> 'individual' OR experience = 'party')", name: "arena_presentation_values"
    add_column :arena_rounds, :playback_generation, :integer, null: false, default: 1
    add_column :arena_rounds, :playbacks, :jsonb, null: false, default: {}
    add_check_constraint :arena_rounds, "playback_generation >= 1 AND jsonb_typeof(playbacks) = 'object'", name: "arena_playback_values"
    remove_check_constraint :arena_memberships, name: "arena_avatar_values"
    add_check_constraint :arena_memberships, "avatar_id::text IN ('neutral','fox','cat','owl','robot','penguin','octopus','rabbit','dog','bear','panda','frog','dragon')", name: "arena_avatar_values"
    remove_check_constraint :arena_question_snapshots, name: "arena_snapshot_contract"
    add_check_constraint :arena_question_snapshots, "payload_version::text IN ('choice-v1','reading-note-v1','reading-visual-v2','music-choice-v3') AND payload_digest ~ '^[0-9a-f]{64}$' AND jsonb_typeof(payload) = 'object' AND (payload_version = 'choice-v1' OR arena_content_version_id IS NOT NULL)", name: "arena_snapshot_contract"
    execute <<~SQL
      CREATE FUNCTION arena_encore_presentation_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.state <> 'draft' AND NEW.presentation_mode IS DISTINCT FROM OLD.presentation_mode THEN
          RAISE EXCEPTION 'Arena presentation is immutable' USING ERRCODE='23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_encore_presentation BEFORE UPDATE ON arena_sessions FOR EACH ROW EXECUTE FUNCTION arena_encore_presentation_guard();
      CREATE FUNCTION arena_encore_capacity_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      DECLARE maximum integer; occupied integer;
      BEGIN
        IF NEW.status = 'active' AND (TG_OP = 'INSERT' OR OLD.status <> 'active') THEN
          SELECT capacity INTO maximum FROM arena_sessions WHERE id=NEW.arena_session_id FOR UPDATE;
          SELECT count(*) INTO occupied FROM arena_memberships WHERE arena_session_id=NEW.arena_session_id AND status='active' AND id<>NEW.id;
          IF occupied >= maximum THEN RAISE EXCEPTION 'Arena is full' USING ERRCODE='23514'; END IF;
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_encore_capacity BEFORE INSERT OR UPDATE ON arena_memberships FOR EACH ROW EXECUTE FUNCTION arena_encore_capacity_guard();
      CREATE FUNCTION arena_encore_playback_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.playback_generation < OLD.playback_generation OR (NEW.playback_generation <> OLD.playback_generation AND NEW.playbacks <> '{}'::jsonb) THEN
          RAISE EXCEPTION 'Invalid Arena playback generation' USING ERRCODE='23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_encore_playback BEFORE UPDATE ON arena_rounds FOR EACH ROW EXECUTE FUNCTION arena_encore_playback_guard();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve expanded rooms, musical snapshots and playback history"
  end
end
