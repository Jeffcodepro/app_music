class EnableArenaAudioCheck < ActiveRecord::Migration[7.1]
  def up
    add_column :arena_sessions, :audio_check_id, :uuid
    add_column :arena_sessions, :audio_check_started_at, :datetime, precision: 6
    add_column :arena_sessions, :audio_check_deadline_at, :datetime, precision: 6
    add_column :arena_sessions, :host_audio_ready_at, :datetime, precision: 6
    add_column :arena_memberships, :audio_ready_at, :datetime, precision: 6
    add_column :arena_memberships, :audio_excluded_at, :datetime, precision: 6
    add_check_constraint :arena_sessions, "(audio_check_id IS NULL AND audio_check_started_at IS NULL AND audio_check_deadline_at IS NULL AND host_audio_ready_at IS NULL) OR (audio_check_id IS NOT NULL AND audio_check_started_at IS NOT NULL AND audio_check_deadline_at IS NOT NULL AND audio_check_deadline_at = audio_check_started_at + interval '45 seconds' AND (host_audio_ready_at IS NULL OR (host_audio_ready_at >= audio_check_started_at AND host_audio_ready_at < audio_check_deadline_at)))", name: "arena_audio_check_timing"
    add_check_constraint :arena_memberships, "audio_excluded_at IS NULL OR (status::text = 'removed' AND audio_ready_at IS NULL)", name: "arena_audio_exclusion"
    execute <<~SQL
      CREATE FUNCTION arena_audio_check_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.audio_check_id IS NOT NULL AND (NEW.audio_check_id IS DISTINCT FROM OLD.audio_check_id OR NEW.audio_check_started_at IS DISTINCT FROM OLD.audio_check_started_at OR NEW.audio_check_deadline_at IS DISTINCT FROM OLD.audio_check_deadline_at) THEN
          RAISE EXCEPTION 'Arena audio preparation cannot be restarted or extended' USING ERRCODE='23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_audio_check BEFORE UPDATE ON arena_sessions FOR EACH ROW EXECUTE FUNCTION arena_audio_check_guard();
      CREATE FUNCTION arena_audio_membership_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      DECLARE starts timestamp; deadline timestamp;
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD.audio_excluded_at IS NOT NULL AND NEW.audio_excluded_at IS DISTINCT FROM OLD.audio_excluded_at THEN
          RAISE EXCEPTION 'Arena audio exclusion cannot be erased' USING ERRCODE='23514';
        END IF;
        IF NEW.audio_ready_at IS NOT NULL THEN
          SELECT audio_check_started_at,audio_check_deadline_at INTO starts,deadline FROM arena_sessions WHERE id=NEW.arena_session_id;
          IF starts IS NULL OR NEW.audio_ready_at < starts OR NEW.audio_ready_at >= deadline THEN
            RAISE EXCEPTION 'Arena readiness requires its preparation window' USING ERRCODE='23514';
          END IF;
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_audio_membership BEFORE INSERT OR UPDATE ON arena_memberships FOR EACH ROW EXECUTE FUNCTION arena_audio_membership_guard();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve audio preparation and admission history"
  end
end
