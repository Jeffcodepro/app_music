require "test_helper"
require "json"
require "open3"
require "tmpdir"

# Exercise the public command, with independent complete snapshots. These tests
# neither generate their expected values with the comparator nor connect to PG.
class MigrationComparisonTest < ActiveSupport::TestCase
  test "A structural equality does not hide changed record fingerprints in full comparison" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("records").fetch("users")["fingerprint"] = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

    assert_comparison "compare-structure", expected, actual, equal: true
    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "records", "users"
  end

  test "A full comparison also detects changed record counts" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("records").fetch("users").merge!(
      "count" => "2", "fingerprint" => "cccccccccccccccccccccccccccccccc"
    )
    actual.fetch("sequence_state").fetch("users_id_seq")["last_value"] = "2"

    assert_comparison "compare-structure", expected, actual, equal: true
    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "records", "users"
  end

  test "B migration history differences are visible only in full scope" do
    expected = reference_snapshot
    actual = copy(expected)
    actual["migrations"] = ["20260325101500"]
    actual.fetch("records").fetch("schema_migrations")["fingerprint"] = "dddddddddddddddddddddddddddddddd"

    assert_comparison "compare-structure", expected, actual, equal: true
    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "migrations"
  end

  test "C a changed last value is detected despite equal records and structure" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("sequence_state").fetch("users_id_seq")["last_value"] = "8"

    assert_comparison "compare-structure", expected, actual, equal: true
    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "sequence_state", "users_id_seq"
  end

  test "C the called flag is part of sequence preservation" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("sequence_state").fetch("users_id_seq")["is_called"] = "f"

    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "sequence_state", "users_id_seq"
  end

  test "D orphan counts remain visible for an existing not validated foreign key" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("foreign_keys").first["orphans"] = 1
    actual.fetch("records").fetch("exercise_attempts")["fingerprint"] = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

    assert_comparison "compare-structure", expected, actual, equal: true
    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "foreign_keys"
  end

  test "E identical complete snapshots pass both scopes with explicit categories" do
    expected = reference_snapshot

    assert_comparison "compare-structure", expected, copy(expected), equal: true
    result = assert_comparison "compare-full", expected, copy(expected), equal: true
    assert_equal({ "expected_orphans" => 0, "actual_orphans" => 0, "healthy" => true }, result.fetch("referential_integrity"))
  end

  test "equal positive orphan counts preserve state without claiming healthy referential integrity" do
    expected = reference_snapshot
    expected.fetch("foreign_keys").first["orphans"] = 1

    result = assert_comparison "compare-full", expected, copy(expected), equal: true
    assert_equal({ "expected_orphans" => 1, "actual_orphans" => 1, "healthy" => false }, result.fetch("referential_integrity"))
  end

  test "migration ordering does not change a complete history of decimal version strings" do
    expected = reference_snapshot
    expected["migrations"] = ["1", "2026032511400", "20260325114000"]
    expected.fetch("records").fetch("schema_migrations").merge!(
      "count" => "3", "fingerprint" => "dddddddddddddddddddddddddddddddd"
    )
    actual = copy(expected)
    actual.fetch("migrations").reverse!

    assert_comparison "compare-structure", expected, actual, equal: true
    assert_comparison "compare-full", expected, actual, equal: true
  end

  test "foreign key ordering does not change the represented constraints" do
    expected = reference_snapshot
    expected.fetch("structure").fetch("constraints")["exercise_attempts.fk_attempts_users_second"] =
      copy(expected.fetch("structure").fetch("constraints").fetch("exercise_attempts.fk_attempts_users"))
    expected.fetch("foreign_keys") << expected.fetch("foreign_keys").first.merge("constraint" => "fk_attempts_users_second")
    actual = copy(expected)
    actual.fetch("foreign_keys").reverse!

    assert_comparison "compare-structure", expected, actual, equal: true
    assert_comparison "compare-full", expected, actual, equal: true
  end

  test "E database provenance is not a preservation difference" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("identity").merge!(
      "database" => "app_music_integrity_restored_test",
      "data_directory" => "/private/tmp/app-music-restored/data",
      "port" => "55440"
    )

    assert_comparison "compare-full", expected, actual, equal: true
  end

  test "Rails internal metadata fingerprints remain part of full preservation" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("records").fetch("ar_internal_metadata")["fingerprint"] = "ffffffffffffffffffffffffffffffff"

    assert_comparison "compare-structure", expected, actual, equal: true
    result = assert_comparison "compare-full", expected, actual, equal: false
    assert_difference result, "records", "ar_internal_metadata"
  end

  test "both scopes report an exact structural difference rather than normalizing it" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("structure").fetch("indexes").fetch("users_pkey")["definition"] =
      "CREATE INDEX users_pkey ON public.users USING btree (id)"

    %w[compare-structure compare-full].each do |command|
      result = assert_comparison command, expected, actual, equal: false
      difference = assert_difference result, "structure", "users_pkey"
      assert_equal "indexes", difference.fetch("subcategory")
    end
  end

  test "legacy compare explicitly warns that it checks structure only" do
    expected = reference_snapshot
    actual = copy(expected)
    actual.fetch("records").fetch("users")["fingerprint"] = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

    stdout, stderr, status = run_comparison "compare", expected, actual
    assert_equal 0, status.exitstatus, stderr
    result = JSON.parse(stdout)
    assert_equal "structure", result.fetch("scope")
    assert_equal ["structure"], result.fetch("categories")
    assert_equal true, result.fetch("equal")
    assert_equal [], result.fetch("differences")
    assert_match(/structur/i, stderr)
    assert_match(/compare-full|integral|full/i, stderr)
  end

  test "F both scopes reject missing snapshot categories including equally truncated inputs" do
    required = %w[identity structure migrations records foreign_keys sequence_state]
    %w[compare-structure compare-full].each do |command|
      required.each do |category|
        incomplete = reference_snapshot
        incomplete.delete(category)
        assert_invalid_snapshot command, reference_snapshot, incomplete
        assert_invalid_snapshot command, incomplete, copy(incomplete)
      end

      incomplete = reference_snapshot
      incomplete.fetch("structure").delete("triggers")
      assert_invalid_snapshot command, incomplete, copy(incomplete)
    end
  end

  test "F malformed types are never reported as equal" do
    malformed_snapshots = [
      ->(s) { s["identity"] = [] },
      ->(s) { s["structure"] = [] },
      ->(s) { s.fetch("structure")["tables"] = [] },
      ->(s) { s.fetch("structure").fetch("columns").fetch("users.id")["not_null"] = true },
      ->(s) { s["migrations"] = {} },
      ->(s) { s["migrations"] = [20260325114000] },
      ->(s) { s["records"] = [] },
      ->(s) { s.fetch("records").fetch("users")["count"] = "many" },
      ->(s) { s.fetch("records").fetch("users")["fingerprint"] = nil },
      ->(s) { s["foreign_keys"] = {} },
      ->(s) { s.fetch("foreign_keys").first["orphans"] = "1" },
      ->(s) { s["sequence_state"] = [] },
      ->(s) { s.fetch("sequence_state").fetch("users_id_seq")["last_value"] = "unknown" },
      ->(s) { s.fetch("sequence_state").fetch("users_id_seq")["is_called"] = "maybe" }
    ]

    %w[compare-structure compare-full].each do |command|
      malformed_snapshots.each do |mutate|
        malformed = reference_snapshot
        mutate.call(malformed)
        assert_invalid_snapshot command, malformed, copy(malformed)
      end
    end
  end

  test "F complete category names cannot conceal missing table sequence or foreign key coverage" do
    mutations = [
      ->(s) { s.fetch("records").delete("users") },
      ->(s) { s.fetch("sequence_state").delete("users_id_seq") },
      ->(s) { s["foreign_keys"] = [] },
      ->(s) { s.fetch("records")["unknown_table"] = { "count" => "0", "fingerprint" => "a" * 32 } },
      ->(s) { s.fetch("foreign_keys") << copy(s.fetch("foreign_keys").first) },
      ->(s) { s.fetch("migrations") << s.fetch("migrations").first }
    ]

    %w[compare-structure compare-full].each do |command|
      mutations.each do |mutate|
        malformed = reference_snapshot
        mutate.call(malformed)
        assert_invalid_snapshot command, malformed, copy(malformed)
      end
    end
  end

  test "F equally missing internal fields are rejected in both scopes" do
    incomplete_paths = [
      %w[identity read_only],
      %w[structure tables users kind],
      %w[structure columns users.id type],
      %w[structure indexes users_pkey definition],
      %w[structure constraints exercise_attempts.fk_attempts_users validated],
      %w[structure sequences users_id_seq owned_table],
      %w[structure extensions plpgsql version],
      %w[records users fingerprint],
      %w[sequence_state users_id_seq last_value]
    ]

    %w[compare-structure compare-full].each do |command|
      incomplete_paths.each do |path|
        malformed = reference_snapshot
        malformed.dig(*path[0...-1]).delete(path.last)
        assert_invalid_snapshot command, malformed, copy(malformed)
      end

      malformed = reference_snapshot
      malformed.fetch("foreign_keys").first.delete("orphans")
      assert_invalid_snapshot command, malformed, copy(malformed)
    end
  end

  test "F unsupported top level and structural categories are rejected instead of ignored" do
    %w[compare-structure compare-full].each do |command|
      malformed = reference_snapshot.merge("unsupported" => {})
      assert_invalid_snapshot command, malformed, copy(malformed)

      malformed = reference_snapshot
      malformed.fetch("structure")["unsupported_objects"] = {}
      assert_invalid_snapshot command, malformed, copy(malformed)
    end
  end

  test "F duplicate JSON keys are rejected before equal values can conceal them" do
    Dir.mktmpdir("app-music-comparison-duplicates-") do |directory|
      valid_path = File.join(directory, "valid.json")
      malformed_path = File.join(directory, "duplicate.json")
      valid_json = JSON.generate(reference_snapshot)
      File.write(valid_path, valid_json)
      duplicate_snapshots = [
        valid_json.sub("\"structure\":", "\"structure\":{},\"structure\":"),
        valid_json.sub("\"read_only\":\"on\"", "\"read_only\":\"on\",\"read_only\":\"on\"")
      ]

      %w[compare-structure compare-full].each do |command|
        duplicate_snapshots.each do |malformed_json|
          File.write(malformed_path, malformed_json)
          stdout, stderr, status = run_cli(command, valid_path, malformed_path)
          assert_equal 2, status.exitstatus, [stdout, stderr].join("\n")
          assert_match(/duplicate/i, stderr)
          refute_match(/"equal"\s*:\s*true/, stdout)
        end
      end
    end
  end

  test "invalid JSON missing files and unexpected CLI arguments fail explicitly" do
    Dir.mktmpdir("app-music-comparison-invalid-") do |directory|
      valid = File.join(directory, "valid.json")
      broken = File.join(directory, "broken.json")
      File.write(valid, JSON.generate(reference_snapshot))
      File.write(broken, "{not valid JSON")

      [
        ["compare-full", valid, broken],
        ["compare-full", valid, File.join(directory, "absent.json")],
        ["compare-full", valid],
        ["compare-structure", valid, valid, "db:drop"]
      ].each do |arguments|
        stdout, stderr, status = run_cli(*arguments)
        assert_equal 2, status.exitstatus, [stdout, stderr].join("\n")
        assert_not_empty stderr
      end
    end
  end

  private

  def assert_comparison(command, expected, actual, equal:)
    stdout, stderr, status = run_comparison(command, expected, actual)
    assert_equal(equal ? 0 : 1, status.exitstatus, [stdout, stderr].join("\n"))
    result = JSON.parse(stdout)
    scope = command == "compare-structure" ? "structure" : "full"
    categories = scope == "structure" ? ["structure"] : %w[structure migrations records foreign_keys sequence_state]
    assert_equal scope, result.fetch("scope")
    assert_equal categories, result.fetch("categories")
    assert_equal equal, result.fetch("equal")
    assert_kind_of Array, result.fetch("differences")
    assert_equal equal, result.fetch("differences").empty?
    result
  end

  def assert_difference(result, category, name = nil)
    difference = result.fetch("differences").find do |entry|
      entry.fetch("category") == category && (name.nil? || entry.fetch("name") == name)
    end
    assert difference, "Expected diagnostic for #{category}/#{name}: #{result.inspect}"
    difference
  end

  def assert_invalid_snapshot(command, expected, actual)
    stdout, stderr, status = run_comparison command, expected, actual
    assert_equal 2, status.exitstatus, [stdout, stderr].join("\n")
    assert_not_empty stderr
    refute_match(/"equal"\s*:\s*true/, stdout)
  end

  def run_comparison(command, expected, actual)
    Dir.mktmpdir("app-music-comparison-") do |directory|
      expected_path = File.join(directory, "expected.json")
      actual_path = File.join(directory, "actual.json")
      File.write(expected_path, JSON.generate(expected))
      File.write(actual_path, JSON.generate(actual))
      run_cli(command, expected_path, actual_path)
    end
  end

  def run_cli(*arguments)
    Open3.capture3(RbConfig.ruby, Rails.root.join("script/migration_reconciliation.rb").to_s, *arguments)
  end

  def copy(value)
    Marshal.load(Marshal.dump(value))
  end

  def reference_snapshot
    table_names = %w[ar_internal_metadata exercise_attempts schema_migrations users]
    table_definition = { "kind" => "r", "persistence" => "p", "row_security" => "f", "force_row_security" => "f" }
    column_definition = {
      "type" => "bigint", "not_null" => "t", "default_expression" => nil,
      "identity" => "", "generated" => "", "collation" => nil
    }
    constraint_definition = { "type" => "p", "definition" => "PRIMARY KEY (id)", "validated" => "t", "deferrable" => "f", "deferred" => "f" }
    sequence_definition = {
      "type" => "bigint", "start" => "1", "increment" => "1", "maximum" => "9223372036854775807",
      "minimum" => "1", "cache" => "1", "cycle" => "f", "owned_column" => "id"
    }

    {
      "identity" => {
        "database" => "app_music_integrity_snapshot_test", "role" => "app_music_auditor",
        "data_directory" => "/private/tmp/app-music-synthetic/data", "port" => "55439",
        "server_version" => "15.19", "read_only" => "on", "tcp_address" => nil, "rails_environment" => "test"
      },
      "structure" => {
        "tables" => table_names.to_h { |name| [name, copy(table_definition)] },
        "columns" => {
          "users.id" => column_definition.merge("default_expression" => "nextval('users_id_seq'::regclass)"),
          "users.email" => column_definition.merge("type" => "character varying", "collation" => "default"),
          "exercise_attempts.id" => column_definition.merge("default_expression" => "nextval('exercise_attempts_id_seq'::regclass)"),
          "exercise_attempts.user_id" => copy(column_definition),
          "ar_internal_metadata.key" => column_definition.merge("type" => "character varying", "collation" => "default"),
          "ar_internal_metadata.value" => column_definition.merge("type" => "character varying", "not_null" => "f", "collation" => "default"),
          "schema_migrations.version" => column_definition.merge("type" => "character varying", "collation" => "default")
        },
        "indexes" => {
          "users_pkey" => { "table_name" => "users", "definition" => "CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id)", "valid" => "t", "ready" => "t" },
          "exercise_attempts_pkey" => { "table_name" => "exercise_attempts", "definition" => "CREATE UNIQUE INDEX exercise_attempts_pkey ON public.exercise_attempts USING btree (id)", "valid" => "t", "ready" => "t" },
          "ar_internal_metadata_pkey" => { "table_name" => "ar_internal_metadata", "definition" => "CREATE UNIQUE INDEX ar_internal_metadata_pkey ON public.ar_internal_metadata USING btree (key)", "valid" => "t", "ready" => "t" },
          "schema_migrations_pkey" => { "table_name" => "schema_migrations", "definition" => "CREATE UNIQUE INDEX schema_migrations_pkey ON public.schema_migrations USING btree (version)", "valid" => "t", "ready" => "t" }
        },
        "constraints" => {
          "users.users_pkey" => copy(constraint_definition),
          "exercise_attempts.exercise_attempts_pkey" => copy(constraint_definition),
          "exercise_attempts.fk_attempts_users" => constraint_definition.merge(
            "type" => "f", "definition" => "FOREIGN KEY (user_id) REFERENCES users(id) NOT VALID", "validated" => "f"
          ),
          "ar_internal_metadata.ar_internal_metadata_pkey" => constraint_definition.merge("definition" => "PRIMARY KEY (key)"),
          "schema_migrations.schema_migrations_pkey" => constraint_definition.merge("definition" => "PRIMARY KEY (version)")
        },
        "sequences" => {
          "users_id_seq" => sequence_definition.merge("owned_table" => "users"),
          "exercise_attempts_id_seq" => sequence_definition.merge("owned_table" => "exercise_attempts")
        },
        "views" => {}, "triggers" => {}, "routines" => {}, "enums" => {},
        "extensions" => { "plpgsql" => { "version" => "1.0" } }
      },
      "migrations" => ["20260325114000"],
      "records" => table_names.to_h { |name| [name, { "count" => "1", "fingerprint" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }] },
      "foreign_keys" => [{ "source" => "exercise_attempts", "target" => "users", "constraint" => "fk_attempts_users", "orphans" => 0 }],
      "sequence_state" => {
        "users_id_seq" => { "last_value" => "1", "is_called" => "t" },
        "exercise_attempts_id_seq" => { "last_value" => "1", "is_called" => "t" }
      }
    }
  end
end
