class EnableArenaListeningSequence < ActiveRecord::Migration[7.1]
  def up
    add_column :arena_sessions, :listening_policy, :string, null: false, default: "manual-v1"
    add_column :arena_sessions, :listening_repetitions, :integer, null: false, default: 3
    add_check_constraint :arena_sessions, "listening_policy::text IN ('manual-v1','sequence-v1') AND listening_repetitions BETWEEN 1 AND 5", name: "arena_listening_configuration"
    add_column :arena_rounds, :listening_started_at, :datetime, precision: 6
    add_column :arena_rounds, :listening_progress, :jsonb, null: false, default: {}
    add_check_constraint :arena_rounds, "jsonb_typeof(listening_progress) = 'object'", name: "arena_listening_progress"
    execute <<~SQL
      CREATE FUNCTION arena_listening_configuration_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.state <> 'draft' AND (NEW.listening_policy IS DISTINCT FROM OLD.listening_policy OR NEW.listening_repetitions IS DISTINCT FROM OLD.listening_repetitions) THEN
          RAISE EXCEPTION 'Arena listening configuration is immutable' USING ERRCODE='23514';
        END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_listening_configuration BEFORE UPDATE ON arena_sessions FOR EACH ROW EXECUTE FUNCTION arena_listening_configuration_guard();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve listening policy and receipts"
  end
end
