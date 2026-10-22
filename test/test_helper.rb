ENV["RAILS_ENV"] ||= "test"
abort "Tests require RAILS_ENV=test" unless ENV["RAILS_ENV"] == "test"
abort "Tests require PARALLEL_WORKERS=1; schema-based worker reconstruction loses Arena protections" unless ENV["PARALLEL_WORKERS"] == "1"
abort "Use bin/test-isolated: inherited DATABASE_URL is not accepted" unless
  !ENV["APP_MUSIC_TEST_DATABASE_URL"].to_s.empty? && ENV["DATABASE_URL"] == ENV["APP_MUSIC_TEST_DATABASE_URL"]
require_relative "../lib/isolated_test_database"
require_relative "../config/environment"
context = ActiveRecord::Base.connection.migration_context
applied = context.get_all_versions
pending = context.migrations.reject { |migration| applied.include?(migration.version) }
raise ActiveRecord::PendingMigrationError.new(pending_migrations: pending) if pending.any?
Arena::SchemaIntegrity.verify! if applied.include?(20261021000000)
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Never reconstruct worker databases from schema.rb: it omits SQL triggers.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
