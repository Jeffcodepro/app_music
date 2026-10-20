ENV["RAILS_ENV"] ||= "test"
abort "Tests require RAILS_ENV=test" unless ENV["RAILS_ENV"] == "test"
abort "Use bin/test-isolated: inherited DATABASE_URL is not accepted" unless
  !ENV["APP_MUSIC_TEST_DATABASE_URL"].to_s.empty? && ENV["DATABASE_URL"] == ENV["APP_MUSIC_TEST_DATABASE_URL"]
require_relative "../lib/isolated_test_database"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
