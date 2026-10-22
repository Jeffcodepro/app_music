require "test_helper"
require "open3"
require "securerandom"
require "uri"
require_relative "../../../script/migration_reconciliation"
require_relative "../../support/arena_legacy_fixture"

class ArenaBaselineBootstrapTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def new_database
    uri = URI.parse(ENV.fetch("APP_MUSIC_TEST_DATABASE_URL"))
    name = "app_music_integrity_arena_#{SecureRandom.hex(5)}_test"
    PG.connect(uri.to_s) { |connection| connection.exec("CREATE DATABASE #{connection.quote_ident(name)}") }
    uri.path = "/#{name}"
    uri.to_s
  end

  def command(url, *args)
    Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => url, "DATABASE_URL" => nil, "SCHEMA" => nil, "RAILS_ENV" => "test", "RACK_ENV" => "test", "CI" => nil },
      RbConfig.ruby, Rails.root.join("bin/arena-baseline").to_s, *args)
  end

  def runner(url, code)
    Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => url, "DATABASE_URL" => url, "SCHEMA" => nil, "RAILS_ENV" => "test", "RACK_ENV" => "test", "CI" => nil },
      RbConfig.ruby, "-rbundler/setup", "-r./lib/isolated_test_database", "-r./config/environment", "-r./lib/arena_baseline/bootstrap", "-e", code, chdir: Rails.root.to_s)
  end

  def snapshot(url)
    PG.connect(url) { |connection| MigrationReconciliation.snapshot(connection, expected_database: URI.parse(url).path.delete_prefix("/"), expected_environment: "test") }
  end

  def migrate(url)
    socket = URI.decode_www_form(URI.parse(url).query).to_h.fetch("host")
    dump = File.join(socket, "#{URI.parse(url).path.delete_prefix('/')}-schema.rb")
    output, status = Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => url, "DATABASE_URL" => nil,
      "SCHEMA" => dump, "RAILS_ENV" => "test", "RACK_ENV" => "test", "CI" => nil },
      RbConfig.ruby, Rails.root.join("bin/test-isolated").to_s, "db:migrate", chdir: Rails.root.to_s)
    assert status.success?, output
    dump
  end

  test "bootstrap records only nine available versions and a second load preserves everything" do
    url = new_database
    output, status = command(url, "bootstrap")
    assert status.success?, output
    before = snapshot(url)
    assert_equal 15, before.fetch("structure").fetch("tables").size
    assert_equal 9, before.fetch("migrations").size
    refute_includes before.fetch("migrations"), "20260320120000"
    output, status = command(url, "bootstrap")
    refute status.success?
    assert_includes output, "UnsafeDestination"
    comparison = MigrationReconciliation.compare(before, snapshot(url), scope: "full")
    assert comparison.fetch("equal"), comparison.fetch("differences").inspect
  end

  test "even empty tables and empty nonpublic schemas prevent loading" do
    ["CREATE TABLE public.sentinel(id integer)", "CREATE SCHEMA sentinel"].each do |sql|
      url = new_database
      PG.connect(url) { |connection| connection.exec(sql) }
      output, status = command(url, "bootstrap")
      refute status.success?, output
      PG.connect(url) do |connection|
        assert_equal "0", connection.exec("SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename='schema_migrations'").getvalue(0, 0)
      end
    end
  end

  test "racing table creation survives without DROP or replacement" do
    url = new_database
    output, status = runner(url, <<~'RUBY')
      begin
        ArenaBaseline::Bootstrap.call(manifest: ArenaBaseline::Manifest.new(root: Dir.pwd), after_empty_check: ->(_connection) {
          PG.connect(ENV.fetch("APP_MUSIC_TEST_DATABASE_URL")) do |other|
            other.exec("CREATE TABLE public.users(id integer PRIMARY KEY, marker text)")
            other.exec("INSERT INTO public.users VALUES (71,'concurrent sentinel')")
            puts "sentinel_oid=#{other.exec("SELECT 'public.users'::regclass::oid").getvalue(0,0)}"
          end
        })
        abort "unsafe success"
      rescue ActiveRecord::StatementInvalid
        puts "safe collision"
      end
    RUBY
    assert status.success?, output
    assert_includes output, "safe collision"
    expected_oid = output[/sentinel_oid=(\d+)/, 1]
    PG.connect(url) do |connection|
      assert_equal expected_oid, connection.exec("SELECT 'public.users'::regclass::oid").getvalue(0, 0)
      assert_equal "concurrent sentinel", connection.exec("SELECT marker FROM users WHERE id=71").getvalue(0, 0)
      assert_equal ["users"], connection.exec("SELECT tablename FROM pg_tables WHERE schemaname='public'").map { |row| row.fetch("tablename") }
    end
  end

  test "failure before commit rolls back application tables and metadata" do
    url = new_database
    output, status = runner(url, <<~'RUBY')
      begin
        ArenaBaseline::Bootstrap.call(manifest: ArenaBaseline::Manifest.new(root: Dir.pwd)) { raise "injected failure" }
        abort "unsafe success"
      rescue RuntimeError => error
        raise unless error.message == "injected failure"
        puts "rolled back"
      end
    RUBY
    assert status.success?, output
    assert_includes output, "rolled back"
    PG.connect(url) do |connection|
      assert_equal "0", connection.exec("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'").getvalue(0, 0)
    end
  end

  test "closed grammar and inherited settings are rejected before loading" do
    output, status = command("postgresql://production.invalid/app_music_production", "bootstrap", "db:drop")
    refute status.success?
    assert_includes output, "Refusing baseline command"
    output, status = command("postgresql://production.invalid/app_music_production", "bootstrap")
    refute status.success?
    assert_includes output, "Refusing tests"
    refute_includes output, "could not translate host"
    output, status = Open3.capture2e({ "SCHEMA" => "/must/not/load.rb", "RAILS_ENV" => "test" }, RbConfig.ruby, Rails.root.join("bin/arena-baseline").to_s, "bootstrap")
    refute status.success?
    assert_includes output, "inherited SCHEMA"
  end

  test "synthetic backup restores identically and additive migration preserves legacy history" do
    source, restored = new_database, new_database
    output, status = command(source, "bootstrap")
    assert status.success?, output
    PG.connect(source) { |connection| ArenaLegacyFixture.seed!(connection) }
    before = snapshot(source)
    socket = URI.decode_www_form(URI.parse(source).query).to_h.fetch("host")
    backup = File.join(socket, "#{URI.parse(source).path.delete_prefix('/')}.dump")
    pg_bin = ENV.fetch("APP_MUSIC_PG_BIN", "")
    tool = ->(name) { pg_bin.empty? ? name : File.join(pg_bin, name) }
    output, status = Open3.capture2e(tool.call("pg_dump"), "--format=custom", "--no-owner", "--no-privileges", "--file", backup, "--dbname", source)
    assert status.success?, output
    File.chmod(0o600, backup)
    # The destination was created empty by this test. Never clean or replace it.
    output, status = Open3.capture2e(tool.call("pg_restore"), "--exit-on-error", "--no-owner", "--no-privileges", "--dbname", restored, backup)
    assert status.success?, output
    comparison = MigrationReconciliation.compare(before, snapshot(restored), scope: "full")
    assert comparison.fetch("equal"), comparison.fetch("differences").inspect
    output, status = command(restored, "bootstrap")
    refute status.success?, output
    assert MigrationReconciliation.compare(before, snapshot(restored), scope: "full").fetch("equal")

    migrate(restored)
    after = snapshot(restored)
    ArenaLegacyFixture::TABLES.each do |table|
      assert_equal before.fetch("records").fetch(table), after.fetch("records").fetch(table)
      %w[tables columns indexes constraints sequences].each do |category|
        select = ->(capture) { capture.fetch("structure").fetch(category).select { |key, value|
          key == table || key.start_with?("#{table}.") || value["table_name"] == table || value["owned_table"] == table
        } }
        assert_equal select.call(before), select.call(after), "Legacy #{category}: #{table}"
      end
      assert_equal before.fetch("sequence_state").fetch("#{table}_id_seq"), after.fetch("sequence_state").fetch("#{table}_id_seq")
    end
    assert_equal before.fetch("records").fetch("users"), after.fetch("records").fetch("users")
    assert_equal before.fetch("sequence_state"), after.fetch("sequence_state")
    assert_equal before.fetch("migrations") + %w[20261021000000 20261022000000 20261023000000 20261024000000 20261025000000 20261026000000 20261027000000 20261028000000], after.fetch("migrations")
    assert_equal 18, after.fetch("structure").fetch("triggers").size
    assert after.fetch("foreign_keys").all? { |fk| fk.fetch("orphans").zero? }

    output, status = runner(restored, <<~'RUBY')
      require_relative "./test/support/arena_foundation_helpers"
      include ArenaFoundationHelpers
      host, student = User.find(701), User.find(702)
      arena_grant(host)
      session = arena_session(host)
      round = answering_round(session)
      arena_membership(session, student)
      Arena::RecordAnswer.call(actor: student, round: round, option_id: "b", idempotency_key: SecureRandom.uuid)
      # Include a real musical match, host answer and successor FK in the dump.
      content = Arena::Catalog.create_preview!
      match = Arena::Game.create!(actor: host, content_version: content, title: "Backup party", question_count: 1,
        duration_seconds: 30, technical_preview: true, experience: "party", host_nickname: "Maestro")
      Arena::Game.command!(actor: host, session: match, command: "start", expected_version: match.lock_version)
      item = match.arena_rounds.sole
      item.update!(answer_open_at: 1.second.ago, deadline_at: 1.minute.from_now)
      Arena::Game.settle!(actor: host, session: match)
      Arena::RecordAnswer.call(actor: host, round: item, option_id: item.arena_question_snapshot.payload.fetch("correct_option_id"), idempotency_key: SecureRandom.uuid)
      Arena::Game.settle!(actor: host, session: match)
      item.reload.update!(advance_at: 1.second.ago)
      Arena::Game.settle!(actor: host, session: match)
      Arena::Catalog.publish!(content: content, reviewer_reference: SecureRandom.uuid)
      Arena::Game.rematch!(actor: host, session: match, expected_version: match.reload.lock_version)
    RUBY
    assert status.success?, output
    with_history = snapshot(restored)
    assert_equal "2", with_history.fetch("records").fetch("arena_answers").fetch("count")
    foundation_copy = new_database
    output, status = Open3.capture2e(tool.call("pg_dump"), "--format=custom", "--no-owner", "--no-privileges", "--file", backup, "--dbname", restored)
    assert status.success?, output
    output, status = Open3.capture2e(tool.call("pg_restore"), "--exit-on-error", "--no-owner", "--no-privileges", "--dbname", foundation_copy, backup)
    assert status.success?, output
    comparison = MigrationReconciliation.compare(with_history, snapshot(foundation_copy), scope: "full")
    assert comparison.fetch("equal"), comparison.fetch("differences").inspect
    output, status = runner(foundation_copy, "Arena::SchemaIntegrity.verify!; puts 'restored protections verified'")
    assert status.success?, output
    assert_includes output, "restored protections verified"
  end

  test "test startup preserves triggers despite schema hash mismatch and fails closed on missing protection" do
    url = new_database
    output, status = command(url, "bootstrap")
    assert status.success?, output
    dump = migrate(url)
    before = snapshot(url)
    assert_equal 18, before.fetch("structure").fetch("triggers").size
    boot = ->(workers = "1") {
      Open3.capture2e({ "APP_MUSIC_TEST_DATABASE_URL" => url, "DATABASE_URL" => url, "SCHEMA" => dump,
        "RAILS_ENV" => "test", "RACK_ENV" => "test", "CI" => nil, "PARALLEL_WORKERS" => workers },
        RbConfig.ruby, "-rbundler/setup", "-r./test/test_helper", "-e", "puts 'read-only test startup'", chdir: Rails.root.to_s)
    }
    output, status = boot.call
    assert status.success?, output
    assert_includes output, "read-only test startup"
    assert MigrationReconciliation.compare(before, snapshot(url), scope: "full").fetch("equal")
    output, status = boot.call("2")
    refute status.success?
    assert_includes output, "PARALLEL_WORKERS=1"
    assert MigrationReconciliation.compare(before, snapshot(url), scope: "full").fetch("equal")

    PG.connect(url) { |connection| connection.exec("ALTER TABLE arena_question_snapshots DISABLE TRIGGER arena_snapshot_immutable") }
    unprotected = snapshot(url)
    output, status = boot.call
    refute status.success?
    assert_includes output, "MissingProtection"
    assert MigrationReconciliation.compare(unprotected, snapshot(url), scope: "full").fetch("equal")
  end

  test "schema protection is rechecked without stale query cache" do
    url = new_database
    output, status = command(url, "bootstrap")
    assert status.success?, output
    migrate(url)
    output, status = runner(url, <<~'RUBY')
      ActiveRecord::Base.cache do
        Arena::SchemaIntegrity.verify!
        PG.connect(ENV.fetch("APP_MUSIC_TEST_DATABASE_URL")) do |other|
          other.exec("SET lock_timeout = '2s'")
          other.exec("ALTER TABLE arena_question_snapshots DISABLE TRIGGER arena_snapshot_immutable")
        end
        begin
          Arena::SchemaIntegrity.verify!
          abort "stale guard accepted"
        rescue Arena::SchemaIntegrity::MissingProtection
          puts "fresh guard refused"
        end
      end
    RUBY
    assert status.success?, output
    assert_includes output, "fresh guard refused"
  end
end
