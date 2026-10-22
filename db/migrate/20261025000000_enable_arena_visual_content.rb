class EnableArenaVisualContent < ActiveRecord::Migration[7.1]
  def up
    remove_check_constraint :arena_question_snapshots, name: "arena_snapshot_contract"
    add_check_constraint :arena_question_snapshots,
      "payload_version::text IN ('choice-v1','reading-note-v1','reading-visual-v2') AND payload_digest ~ '^[0-9a-f]{64}$' AND jsonb_typeof(payload) = 'object' AND (payload_version = 'choice-v1' OR arena_content_version_id IS NOT NULL)",
      name: "arena_snapshot_contract"
  end

  def down
    if select_value("SELECT EXISTS(SELECT 1 FROM arena_question_snapshots WHERE payload_version='reading-visual-v2')")
      raise ActiveRecord::IrreversibleMigration, "Preserve visual snapshots before reverting their contract"
    end
    remove_check_constraint :arena_question_snapshots, name: "arena_snapshot_contract"
    add_check_constraint :arena_question_snapshots,
      "payload_version::text IN ('choice-v1','reading-note-v1') AND payload_digest ~ '^[0-9a-f]{64}$' AND jsonb_typeof(payload) = 'object' AND (payload_version <> 'reading-note-v1' OR arena_content_version_id IS NOT NULL)",
      name: "arena_snapshot_contract"
  end
end
