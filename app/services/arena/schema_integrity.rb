module Arena
  class SchemaIntegrity
    class MissingProtection < StandardError; end
    TRIGGERS = {
      "arena_account_removal" => ["users", "arena_f1_anonymize_account"],
      "arena_snapshot_immutable" => ["arena_question_snapshots", "arena_f1_immutable_history"],
      "arena_answer_immutable" => ["arena_answers", "arena_f1_immutable_history"],
      "arena_event_immutable" => ["arena_events", "arena_f1_event_guard"],
      "arena_grant_history" => ["arena_host_grants", "arena_f1_grant_guard"],
      "arena_membership_identity" => ["arena_memberships", "arena_f1_membership_guard"],
      "arena_session_identity" => ["arena_sessions", "arena_f1_session_guard"],
      "arena_round_identity" => ["arena_rounds", "arena_f1_round_guard"]
    }.freeze

    def self.verify!
      connection = ActiveRecord::Base.connection
      connection.uncached do
        rows = connection.select_rows(<<~SQL)
          SELECT t.tgname,c.relname,p.proname,t.tgenabled
          FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_proc p ON p.oid=t.tgfoid
          WHERE n.nspname='public' AND NOT t.tgisinternal
        SQL
        enabled = rows.select { |row| %w[O A].include?(row.last) }.to_h { |name, table, function, _| [name, [table, function]] }
        expected = TRIGGERS.dup
        if connection.select_value("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='20261022000000')")
          expected["arena_content_immutable"] = ["arena_content_versions", "arena_pilot_content_guard"]
        end
        if connection.select_value("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='20261024000000')")
          expected["arena_account_removal"] = ["users", "arena_social_anonymize_account"]
          expected["arena_social_configuration"] = ["arena_sessions", "arena_social_configuration_guard"]
          expected["arena_social_avatar"] = ["arena_memberships", "arena_social_avatar_guard"]
          expected["arena_social_timing"] = ["arena_answers", "arena_social_timing_guard"]
        end
        if connection.select_value("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='20261026000000')")
          expected["arena_encore_presentation"] = ["arena_sessions", "arena_encore_presentation_guard"]
          expected["arena_encore_capacity"] = ["arena_memberships", "arena_encore_capacity_guard"]
          expected["arena_encore_playback"] = ["arena_rounds", "arena_encore_playback_guard"]
        end
        if connection.select_value("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='20261027000000')")
          expected["arena_listening_configuration"] = ["arena_sessions", "arena_listening_configuration_guard"]
        end
        if connection.select_value("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='20261028000000')")
          expected["arena_audio_check"] = ["arena_sessions", "arena_audio_check_guard"]
          expected["arena_audio_membership"] = ["arena_memberships", "arena_audio_membership_guard"]
        end
        unless expected.all? { |name, wiring| enabled[name] == wiring } && connection.select_value("SHOW session_replication_role") == "origin"
          raise MissingProtection, "Arena requires baseline plus its migration; schema.rb alone does not preserve database protections"
        end
      end
      true
    end
  end
end
