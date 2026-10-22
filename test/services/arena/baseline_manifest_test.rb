require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"
require_relative "../../../lib/arena_baseline/manifest"

class ArenaBaselineManifestTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def with_copy
    Dir.mktmpdir("arena-manifest-") do |root|
      paths = ["docs/arena/baseline-manifest.json", "db/schema.rb", *Dir.glob("db/migrate/*.rb", base: ROOT)]
      paths.each do |path|
        FileUtils.mkdir_p(File.dirname(File.join(root, path)))
        FileUtils.cp(File.join(ROOT, path), File.join(root, path))
      end
      yield root, ArenaBaseline::Manifest.new(root: root, repository: ROOT)
    end
  end

  def test_pinned_schema_and_nine_historical_migrations_verify_without_a_database
    manifest = ArenaBaseline::Manifest.new(root: ROOT).verify!
    assert_equal 9, manifest.versions.size
    assert_equal 13, manifest.table_names.size
    assert_equal "20261020000000", manifest.cutoff
    refute_includes manifest.versions, "20260320120000"
  end

  def test_modified_historical_file_is_rejected
    with_copy do |root, manifest|
      File.open(File.join(root, "db/migrate/20261020000000_create_daily_visits.rb"), "a") { |file| file.puts "# changed" }
      assert_raises(ArenaBaseline::InvalidManifest) { manifest.verify! }
    end
  end

  def test_unrecorded_historical_migration_is_rejected
    with_copy do |root, manifest|
      File.write(File.join(root, "db/migrate/20260320120000_invented.rb"), "raise 'must not execute'\n")
      assert_raises(ArenaBaseline::InvalidManifest) { manifest.verify! }
    end
  end

  def test_new_migrations_remain_outside_bootstrap
    with_copy do |root, manifest|
      File.write(File.join(root, "db/migrate/20261021000000_future.rb"), "raise 'must not execute'\n")
      assert_equal 9, manifest.verify!.versions.size
    end
  end

  def test_modified_working_schema_does_not_replace_immutable_source
    with_copy do |root, manifest|
      File.write(File.join(root, "db/schema.rb"), "raise 'must not execute'\n")
      assert_includes manifest.verify!.schema, "create_table \"arena_rooms\""
    end
  end

  def test_unapproved_execution_is_rejected
    with_copy do |root, manifest|
      path = File.join(root, "docs/arena/baseline-manifest.json")
      data = JSON.parse(File.read(path)).merge("execution_authorized" => false)
      File.write(path, JSON.generate(data))
      assert_raises(ArenaBaseline::InvalidManifest) { manifest.verify!(execution: true) }
    end
  end

  def test_blob_and_missing_history_are_checked
    with_copy do |root, manifest|
      path = File.join(root, "docs/arena/baseline-manifest.json")
      data = JSON.parse(File.read(path))
      original_blob = data["schema"]["git_blob"]
      data["schema"]["git_blob"] = "0" * 40
      File.write(path, JSON.generate(data))
      assert_raises(ArenaBaseline::InvalidManifest) { manifest.verify! }
      data["schema"]["git_blob"] = original_blob
      data["missing_original_migrations"][1]["version"] = data["missing_original_migrations"][0]["version"]
      File.write(path, JSON.generate(data))
      assert_raises(ArenaBaseline::InvalidManifest) { manifest.verify! }
    end
  end

  def test_duplicate_json_keys_are_not_authorization
    with_copy do |root, manifest|
      path = File.join(root, "docs/arena/baseline-manifest.json")
      File.write(path, File.read(path).sub(/\{/, '{"execution_authorized":false,'))
      assert_raises(ArenaBaseline::InvalidManifest) { manifest.verify!(execution: true) }
    end
  end
end
