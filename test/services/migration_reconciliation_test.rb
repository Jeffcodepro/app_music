require "test_helper"
require "open3"
require_relative "../../script/migration_reconciliation"

class MigrationReconciliationTest < ActiveSupport::TestCase
  def with_audit_connection
    PG.connect(ENV.fetch("APP_MUSIC_TEST_DATABASE_URL")) { |connection| yield connection }
  end

  test "catalog snapshot is read only and does not expose record contents" do
    with_audit_connection do |connection|
      snapshot = MigrationReconciliation.snapshot(connection, expected_database: connection.db, expected_environment: "test")
      assert_equal "on", snapshot.dig("identity", "read_only")
      assert_nil snapshot.dig("identity", "tcp_address")
      assert snapshot.dig("structure", "columns").key?("users.encrypted_password")
      assert snapshot.dig("structure", "constraints").keys.any? { |key| key.start_with?("exercise_attempts.") }
      assert_equal %w[count fingerprint], snapshot.fetch("records").fetch("users").keys.sort
      assert_equal 0, snapshot.fetch("foreign_keys").sum { |key| key.fetch("orphans") }
      assert_equal PG::PQTRANS_IDLE, connection.transaction_status
    end
  end

  test "unexpected database or Rails environment is refused and transaction rolled back" do
    with_audit_connection do |connection|
      [["app_music_production", "test"], [connection.db, "production"]].each do |database, environment|
        assert_raises(RuntimeError) do
          MigrationReconciliation.snapshot(connection, expected_database: database, expected_environment: environment)
        end
        assert_equal PG::PQTRANS_IDLE, connection.transaction_status
      end
    end
  end

  test "comparison reports a missing legacy column and a modified uniqueness definition" do
    with_audit_connection do |connection|
      expected = MigrationReconciliation.snapshot(connection, expected_database: connection.db, expected_environment: "test")
      actual = Marshal.load(Marshal.dump(expected))
      actual.fetch("structure").fetch("columns").delete("users.email")
      actual.fetch("structure").fetch("indexes").fetch("index_users_on_email")["definition"].sub!("UNIQUE ", "")
      differences = MigrationReconciliation.compare(expected, actual, scope: "structure").fetch("differences")
      assert_equal [["columns", "users.email", "missing"], ["indexes", "index_users_on_email", "changed"]],
                   differences.map { |difference| difference.values_at("subcategory", "name", "status") }
    end
  end

  test "audit CLI rejects overrides without connecting to development" do
    output, status = Open3.capture2e(RbConfig.ruby, Rails.root.join("script/migration_reconciliation.rb").to_s,
                                    "snapshot-development", "DATABASE_URL=postgresql://production.invalid/app_music_production")
    assert_equal 2, status.exitstatus
    assert_includes output, "Usage:"
    assert_not_includes output, "connection to server"
  end

  test "test snapshot rejects a remote connection before contacting it" do
    output, status = Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => "postgresql://production.invalid/app_music_production" },
                                    RbConfig.ruby, Rails.root.join("script/migration_reconciliation.rb").to_s, "snapshot-test")
    assert_not status.success?
    assert_includes output, "Refusing tests"
    assert_not_includes output, "could not translate host"
  end
end
