require "test_helper"
require "digest"

class MigrationRecoveryTest < ActiveSupport::TestCase
  ORIGINALS = {
    "20260325101500_add_performance_fields_to_study_activities.rb" => "959e064992a66305fcffe4b56fa00ede7ca4f7ec1496ad1d209d7f6b179a9b89",
    "20260325114000_create_playground_attempts.rb" => "03179fcad6aa1058d5e4e620b9932770ddd74b977259b3980575db43eb99a39d"
  }.freeze

  test "recovered files retain the complete historically observed contents" do
    ORIGINALS.each do |name, digest|
      path = Rails.root.join("db/migrate", name)
      assert path.file?, "Missing recovered original #{name}"
      assert_equal digest, Digest::SHA256.file(path).hexdigest
    end
  end

  test "original migrations preserve legacy rows and backfill only eligible attempts" do
    ORIGINALS.each_key do |name|
      path = Rails.root.join("db/migrate", name)
      assert path.file?, "Missing recovered original #{name}"
      require path.to_s
    end
    connection = ActiveRecord::Base.connection
    previous_path = connection.schema_search_path
    namespace = "migration_recovery_#{SecureRandom.hex(6)}"
    connection.create_schema(namespace)
    connection.schema_search_path = "#{namespace}, public"
    ActiveRecord::Migration.suppress_messages do
      connection.create_table(:users)
      connection.create_table(:study_activities) do |table|
        table.bigint :user_id, null: false
        table.string :area, null: false
        table.date :occurred_on, null: false
        table.timestamps null: false
      end
      connection.execute("INSERT INTO users (id) VALUES (1)")
      connection.execute("INSERT INTO study_activities (user_id, area, occurred_on, created_at, updated_at) VALUES (1, 'leitura', '2026-03-25', '2026-03-25 12:00:00', '2026-03-25 12:01:00')")
      AddPerformanceFieldsToStudyActivities.new.migrate(:up)
      legacy = connection.select_one("SELECT source, correct FROM study_activities")
      assert_equal "legacy", legacy.fetch("source")
      assert_nil legacy.fetch("correct")
      connection.execute(<<~SQL)
        INSERT INTO study_activities (user_id, area, occurred_on, source, correct, created_at, updated_at) VALUES
          (1, 'leitura', '2026-03-25', 'playground', true, '2026-03-25 12:00:00', '2026-03-25 12:02:00'),
          (1, 'percepcao', '2026-03-25', 'playground', false, '2026-03-25 12:00:00', '2026-03-25 12:03:00'),
          (1, 'historia', '2026-03-25', 'playground', true, '2026-03-25 12:00:00', '2026-03-25 12:04:00'),
          (1, 'harmonia', '2026-03-25', 'playground', NULL, '2026-03-25 12:00:00', '2026-03-25 12:05:00'),
          (1, 'ritmica', '2026-03-25', 'legacy', true, '2026-03-25 12:00:00', '2026-03-25 12:06:00')
      SQL
      CreatePlaygroundAttempts.new.migrate(:up)
    end
    assert_equal 6, connection.select_value("SELECT count(*) FROM study_activities")
    attempts = connection.select_all("SELECT activity, area, correct, answered_at = updated_at AS time_preserved, metadata = '{}'::jsonb AS metadata_preserved FROM playground_attempts ORDER BY id").to_a
    assert_equal %w[leitura percepcao], attempts.pluck("activity")
    assert_equal %w[leitura percepcao], attempts.pluck("area")
    assert_equal [true, false], attempts.pluck("correct")
    assert attempts.all? { |attempt| attempt.fetch("time_preserved") && attempt.fetch("metadata_preserved") }
    assert connection.indexes("#{namespace}.playground_attempts").any? { |index| index.columns == %w[user_id activity occurred_on] }
    assert_equal "users", connection.foreign_keys("#{namespace}.playground_attempts").sole.to_table
  ensure
    connection.schema_search_path = previous_path if connection && previous_path
    connection&.schema_cache&.clear!
    # The surrounding Rails test transaction rolls back the temporary schema,
    # tables and records. The runner has already proved database isolation.
  end
end
