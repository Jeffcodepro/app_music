require "test_helper"
require "open3"
require_relative "../../lib/isolated_test_command"
require "tmpdir"
require "fileutils"
require "minitest/mock"

class IsolatedTestDatabaseSafetyTest < ActiveSupport::TestCase
  test "production or remote URLs are refused before connecting" do
    output, status = Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => "postgresql://production.invalid/app_music_production" },
                                    RbConfig.ruby, Rails.root.join("bin/test-isolated").to_s)
    assert_not status.success?
    assert_includes output, "Refusing tests"
    assert_not_includes output, "could not translate host"
  end

  test "caller cannot override test environment through rake arguments" do
    output, status = Open3.capture2e(RbConfig.ruby, Rails.root.join("bin/test-isolated").to_s,
                                    "db:migrate", "RAILS_ENV=production")
    assert_not status.success?
    assert_includes output, "Refusing command"
  end

  test "migration commands refuse every extra task before connecting" do
    %w[db:drop db:reset db:seed test db:migrate:status].each do |extra|
      output, status = Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => "postgresql:///not_connected" },
                                      RbConfig.ruby, Rails.root.join("bin/test-isolated").to_s, "db:migrate", extra)
      assert_not status.success?
      assert_includes output, "Refusing command"
    end
  end

  test "closed command grammar permits known tasks paths and minitest filters" do
    [[], ["test"], ["db:migrate"], ["db:migrate:status"], ["db:version"],
     ["test", "test/services", "--seed", "123", "--name", "/integrity/", "-v"],
     ["test", "test/services/exercise_submission_test.rb:28"]].each do |args|
      assert IsolatedTestCommand.allowed?(args), args.inspect
    end
    [["test", "db:drop"], ["test", "--", "db:drop"], ["test", "--environment=production"],
     ["test", "RAILS_ENV=production"], ["db:version", "test"], ["db:migrate", "VERSION=0"],
     ["test", "--seed"], ["test", "--require", "evil.rb"], ["test", "test/../config/environment.rb"]].each do |args|
      assert_not IsolatedTestCommand.allowed?(args), args.inspect
    end
  end

  test "invalid socket URL variants fail before libpq connects" do
    ["postgresql:///app_music_development?host=/private/tmp/x&port=55441&user=test",
     "postgresql:///app_music_integrity_test?host=/tmp/x&host=/tmp/y&port=55441&user=test",
     "postgresql:///app_music_integrity_test?host=/tmp/x&hostaddr=127.0.0.1&port=55441&user=test",
     "postgresql:///app_music_integrity_test?host=/tmp/x&service=production&port=55441&user=test"].each do |url|
      output, status = Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => url }, RbConfig.ruby, Rails.root.join("bin/test-isolated").to_s)
      assert_not status.success?
      assert_includes output, "Refusing tests"
      assert_not_includes output, "connection to server"
    end
  end

  test "a lookalike private directory cannot attest a different server or TCP listener" do
    previous_url = ENV["APP_MUSIC_TEST_DATABASE_URL"]
    Dir.mktmpdir("review-scratch-") do |temporary|
      root = File.realpath(temporary)
      data = File.join(root, "data")
      other = File.join(root, "other")
      Dir.mkdir(data, 0o700)
      Dir.mkdir(other, 0o700)
      File.write(File.join(data, "PG_VERSION"), "15\n")
      ENV["APP_MUSIC_TEST_DATABASE_URL"] = "postgresql:///app_music_integrity_guard_test?#{URI.encode_www_form(host: root, port: 55442, user: 'test')}"
      [{ "directory" => other, "listeners" => "" }, { "directory" => data, "listeners" => "localhost" }].each do |actual|
        connection = Object.new
        connection.define_singleton_method(:exec) { |_sql| [actual.merge("database" => "app_music_integrity_guard_test")] }
        PG.stub(:connect, ->(_url, &block) { block.call(connection) }) do
          _out, err = capture_io do
            assert_raises(SystemExit) { load Rails.root.join("lib/isolated_test_database.rb") }
          end
          assert_includes err, "not the dedicated temporary cluster"
        end
      end
      File.chmod(0o755, root)
      PG.stub(:connect, ->(*) { flunk "must refuse public directories before connecting" }) do
        _out, err = capture_io { assert_raises(SystemExit) { load Rails.root.join("lib/isolated_test_database.rb") } }
        assert_includes err, "Refusing tests"
      end
      File.chmod(0o700, root)
    end
  ensure
    ENV["APP_MUSIC_TEST_DATABASE_URL"] = previous_url
  end
end
