class EnableArenaPilot < ActiveRecord::Migration[7.1]
  def up
    create_table :arena_content_versions, id: :uuid do |t|
      t.string :code, null: false
      t.integer :revision, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :body, null: false
      t.string :content_digest, null: false
      t.string :source_digest, null: false
      t.uuid :reviewer_reference
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :arena_content_versions, [:code, :revision], unique: true, name: "arena_content_revision"
    add_check_constraint :arena_content_versions, "revision > 0 AND status::text IN ('draft','technical_preview','published','archived') AND jsonb_typeof(body) = 'object' AND content_digest ~ '^[0-9a-f]{64}$' AND source_digest ~ '^[0-9a-f]{64}$'", name: "arena_content_values"
    add_check_constraint :arena_content_versions, "(reviewer_reference IS NULL) = (reviewed_at IS NULL) AND (status <> 'published' OR reviewer_reference IS NOT NULL)", name: "arena_content_review"

    add_reference :arena_sessions, :arena_content_version, type: :uuid, foreign_key: true
    add_column :arena_sessions, :invite_digest, :string
    add_column :arena_sessions, :invite_ciphertext, :text
    add_column :arena_sessions, :invite_expires_at, :datetime
    add_column :arena_sessions, :duration_seconds, :integer
    add_index :arena_sessions, :invite_digest, unique: true, where: "invite_digest IS NOT NULL", name: "arena_unique_invite"
    add_index :arena_sessions, [:id, :arena_content_version_id], unique: true, name: "arena_session_content_identity"
    add_check_constraint :arena_sessions, "(invite_digest IS NULL AND invite_ciphertext IS NULL AND invite_expires_at IS NULL) OR (invite_digest IS NOT NULL AND invite_digest ~ '^[0-9a-f]{64}$' AND invite_ciphertext IS NOT NULL AND invite_expires_at IS NOT NULL AND invite_expires_at > created_at)", name: "arena_invite_values"
    add_check_constraint :arena_sessions, "duration_seconds IS NULL OR duration_seconds BETWEEN 15 AND 120", name: "arena_duration_values"
    add_check_constraint :arena_sessions, "arena_content_version_id IS NULL OR (duration_seconds IS NOT NULL AND invite_digest IS NOT NULL AND invite_ciphertext IS NOT NULL AND invite_expires_at IS NOT NULL)", name: "arena_pilot_configuration"
    add_reference :arena_question_snapshots, :arena_content_version, type: :uuid, foreign_key: true
    add_foreign_key :arena_question_snapshots, :arena_sessions,
      column: [:arena_session_id, :arena_content_version_id], primary_key: [:id, :arena_content_version_id], name: "arena_snapshot_content_same_session"
    remove_check_constraint :arena_question_snapshots, name: "arena_snapshot_contract"
    add_check_constraint :arena_question_snapshots, "payload_version::text IN ('choice-v1','reading-note-v1') AND payload_digest ~ '^[0-9a-f]{64}$' AND jsonb_typeof(payload) = 'object' AND (payload_version <> 'reading-note-v1' OR arena_content_version_id IS NOT NULL)", name: "arena_snapshot_contract"

    create_table :arena_rate_windows, id: :uuid do |t|
      t.string :key_digest, null: false
      t.datetime :window_at, null: false
      t.integer :attempts, null: false
      t.datetime :expires_at, null: false
    end
    add_index :arena_rate_windows, [:key_digest, :window_at], unique: true, name: "arena_rate_window_identity"
    add_index :arena_rate_windows, :expires_at
    add_check_constraint :arena_rate_windows, "key_digest ~ '^[0-9a-f]{64}$' AND attempts > 0 AND expires_at > window_at", name: "arena_rate_values"

    execute <<~SQL
      CREATE FUNCTION arena_pilot_content_guard() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.status IN ('technical_preview','published','archived') THEN
          IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'Frozen Arena content cannot be deleted' USING ERRCODE = '23514'; END IF;
          IF (to_jsonb(NEW) - 'status' - 'updated_at' - 'reviewer_reference' - 'reviewed_at') IS DISTINCT FROM
             (to_jsonb(OLD) - 'status' - 'updated_at' - 'reviewer_reference' - 'reviewed_at') OR
             (OLD.status = 'published' AND (NEW.status NOT IN ('published','archived') OR NEW.reviewer_reference IS DISTINCT FROM OLD.reviewer_reference OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at)) OR
             (OLD.status = 'archived' AND NEW.status <> 'archived') OR
             (OLD.status IN ('published','archived') AND (NEW.reviewer_reference IS DISTINCT FROM OLD.reviewer_reference OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at)) OR
             (OLD.status = 'technical_preview' AND NEW.status NOT IN ('technical_preview','published','archived')) THEN
            RAISE EXCEPTION 'Frozen Arena content cannot be rewritten' USING ERRCODE = '23514';
          END IF;
        END IF;
        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER arena_content_immutable BEFORE UPDATE OR DELETE ON arena_content_versions
        FOR EACH ROW EXECUTE FUNCTION arena_pilot_content_guard();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Arena content and invitations require a reviewed preservation plan"
  end
end
