class EnableArenaParty < ActiveRecord::Migration[7.1]
  def up
    add_column :arena_sessions, :experience, :string, null: false, default: "facilitated"
    add_check_constraint :arena_sessions, "experience::text IN ('facilitated','party')", name: "arena_experience_values"
    add_reference :arena_sessions, :rematch_session, type: :uuid, foreign_key: { to_table: :arena_sessions }, index: { unique: true }
    add_check_constraint :arena_sessions, "rematch_session_id IS NULL OR (rematch_session_id <> id AND state::text = 'completed'::text)", name: "arena_rematch_completed"
    add_column :arena_rounds, :advance_at, :datetime
    add_check_constraint :arena_rounds, "advance_at IS NULL OR state::text = 'results'::text", name: "arena_result_advance"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Preserve completed Arena matches and rematch references before rollback"
  end
end
