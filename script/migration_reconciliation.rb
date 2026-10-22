#!/usr/bin/env ruby
# Read-only catalog audit. Never boots Rails or runs migrations against development.
require "json"
require "etc"
require_relative "../lib/migration_snapshot_comparison"

module MigrationReconciliation
  QUERIES = {
    "tables" => <<~SQL,
      SELECT c.relname AS name, c.relkind AS kind, c.relpersistence AS persistence,
             c.relrowsecurity AS row_security, c.relforcerowsecurity AS force_row_security
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') ORDER BY c.relname
    SQL
    "columns" => <<~SQL,
      SELECT c.relname || '.' || a.attname AS name,
             format_type(a.atttypid, a.atttypmod) AS type, a.attnotnull AS not_null,
             pg_get_expr(d.adbin, d.adrelid) AS default_expression,
             a.attidentity AS identity, a.attgenerated AS generated,
             co.collname AS collation
      FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
      LEFT JOIN pg_collation co ON co.oid = a.attcollation
      WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY c.relname, a.attname
    SQL
    "indexes" => <<~SQL,
      SELECT i.relname AS name, t.relname AS table_name, pg_get_indexdef(x.indexrelid) AS definition,
             x.indisvalid AS valid, x.indisready AS ready
      FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid
      JOIN pg_class t ON t.oid = x.indrelid JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'public' ORDER BY i.relname
    SQL
    "constraints" => <<~SQL,
      SELECT c.relname || '.' || k.conname AS name, k.contype AS type,
             pg_get_constraintdef(k.oid) AS definition, k.convalidated AS validated,
             k.condeferrable AS deferrable, k.condeferred AS deferred
      FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' ORDER BY c.relname, k.conname
    SQL
    "sequences" => <<~SQL,
      SELECT c.relname AS name, format_type(s.seqtypid, NULL) AS type,
             s.seqstart AS start, s.seqincrement AS increment, s.seqmax AS maximum,
             s.seqmin AS minimum, s.seqcache AS cache, s.seqcycle AS cycle,
             t.relname AS owned_table, a.attname AS owned_column
      FROM pg_sequence s JOIN pg_class c ON c.oid = s.seqrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_depend d ON d.objid = c.oid AND d.classid = 'pg_class'::regclass
        AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a','i')
      LEFT JOIN pg_class t ON t.oid = d.refobjid
      LEFT JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
      WHERE n.nspname = 'public' ORDER BY c.relname
    SQL
    "views" => <<~SQL,
      SELECT c.relname AS name, c.relkind AS kind, pg_get_viewdef(c.oid) AS definition
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind IN ('v','m') ORDER BY c.relname
    SQL
    "triggers" => <<~SQL,
      SELECT c.relname || '.' || t.tgname AS name, pg_get_triggerdef(t.oid) AS definition, t.tgenabled AS enabled
      FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND NOT t.tgisinternal ORDER BY c.relname, t.tgname
    SQL
    "routines" => <<~SQL,
      SELECT p.oid::regprocedure::text AS name, pg_get_functiondef(p.oid) AS definition
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.prokind IN ('f','p') ORDER BY 1
    SQL
    "enums" => <<~SQL,
      SELECT t.typname || '.' || e.enumsortorder::text AS name, e.enumlabel AS label
      FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
      JOIN pg_namespace n ON n.oid = t.typnamespace WHERE n.nspname = 'public' ORDER BY 1
    SQL
    "extensions" => "SELECT extname AS name, extversion AS version FROM pg_extension ORDER BY extname"
  }.freeze

  def self.compare(expected, actual, scope:)
    MigrationSnapshotComparison.compare(expected, actual, scope:)
  end

  def self.snapshot(connection, expected_database:, expected_environment:)
    connection.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
    connection.exec("SET LOCAL search_path = public; SET LOCAL statement_timeout = '30s'; SET LOCAL lock_timeout = '2s'; SET LOCAL row_security = off")
    identity = connection.exec(<<~SQL).first
      SELECT current_database() AS database, current_user AS role,
             current_setting('data_directory') AS data_directory,
             current_setting('port') AS port, current_setting('server_version') AS server_version,
             current_setting('transaction_read_only') AS read_only,
             inet_server_addr()::text AS tcp_address
    SQL
    raise "Unexpected database identity" unless identity.fetch("database") == expected_database && identity.fetch("read_only") == "on" && identity["tcp_address"].nil?
    environment = connection.exec("SELECT value FROM ar_internal_metadata WHERE key = 'environment'").first&.fetch("value")
    raise "Unexpected Rails environment" unless environment == expected_environment
    structure = QUERIES.to_h do |category, sql|
      [category, connection.exec(sql).to_h { |row| [row.fetch("name"), row.reject { |k, _| k == "name" }] }]
    end
    records = structure.fetch("tables").keys.to_h do |table|
      quoted = connection.quote_ident(table)
      row = connection.exec(<<~SQL).first
        SELECT count(*) AS count,
               md5(COALESCE(string_agg(md5(row_to_json(r)::text), '' ORDER BY md5(row_to_json(r)::text)), '')) AS fingerprint
        FROM public.#{quoted} r
      SQL
      [table, row]
    end
    foreign_keys = connection.exec(<<~SQL).map do |fk|
      SELECT c.relname AS source, t.relname AS target, k.conname AS name,
        target_namespace.nspname AS target_schema, k.confmatchtype AS match_type,
        (SELECT string_agg(format('s.%I IS NOT NULL', a.attname), ' AND ' ORDER BY keys.position)
         FROM unnest(k.conkey) WITH ORDINALITY keys(num, position)
         JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = keys.num) AS present,
        (SELECT string_agg(format('s.%I = t.%I', a.attname, b.attname), ' AND ' ORDER BY keys.position)
         FROM unnest(k.conkey, k.confkey) WITH ORDINALITY keys(source_num, target_num, position)
         JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = keys.source_num
         JOIN pg_attribute b ON b.attrelid = k.confrelid AND b.attnum = keys.target_num) AS matching
      FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid JOIN pg_class t ON t.oid = k.confrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_namespace target_namespace ON target_namespace.oid = t.relnamespace
      WHERE n.nspname = 'public' AND k.contype = 'f' ORDER BY c.relname, k.conname
    SQL
      unless fk.fetch("target_schema") == "public" && fk.fetch("match_type") == "s"
        raise MigrationSnapshotComparison::InvalidSnapshot, "Unsupported foreign key #{fk.fetch('source')}.#{fk.fetch('name')}: capture requires MATCH SIMPLE within public"
      end
      count = connection.exec("SELECT count(*) FROM public.#{connection.quote_ident(fk.fetch('source'))} s WHERE #{fk.fetch('present')} AND NOT EXISTS (SELECT 1 FROM public.#{connection.quote_ident(fk.fetch('target'))} t WHERE #{fk.fetch('matching')})").getvalue(0, 0)
      { "source" => fk.fetch("source"), "target" => fk.fetch("target"), "constraint" => fk.fetch("name"), "orphans" => count.to_i }
    end
    sequence_state = structure.fetch("sequences").keys.to_h do |name|
      [name, connection.exec("SELECT last_value, is_called FROM public.#{connection.quote_ident(name)}").first]
    end
    captured = { "identity" => identity.merge("rails_environment" => environment), "structure" => structure,
      "migrations" => connection.exec("SELECT version FROM schema_migrations ORDER BY version").map { |r| r.fetch("version") },
      "records" => records, "foreign_keys" => foreign_keys, "sequence_state" => sequence_state }
    MigrationSnapshotComparison.validate!(captured)
    captured
  ensure
    connection.exec("ROLLBACK") if connection && connection.transaction_status != PG::PQTRANS_IDLE
  end

  def self.main(arguments)
    case arguments
    in ["compare" | "compare-structure" | "compare-full" => command, expected_path, actual_path]
      scope = command == "compare-full" ? "full" : "structure"
      warn "Legacy compare checks structure only; use compare-full for preservation of data, migrations and sequences." if command == "compare"
      expected, actual = [expected_path, actual_path].map { |path| MigrationSnapshotComparison.read(path) }
      result = compare(expected, actual, scope:)
      puts JSON.pretty_generate(result)
      result.fetch("equal") ? 0 : 1
    in ["snapshot-development"]
      ENV.keys.grep(/\APG/).each { |key| ENV.delete(key) }
      require "pg"
      PG.connect(host: "/tmp", port: 5432, user: Etc.getpwuid.name, dbname: "app_music_development", connect_timeout: 5,
                 options: "-c default_transaction_read_only=on") do |connection|
        directory = connection.exec("SHOW data_directory").getvalue(0, 0)
        raise "Unexpected local PostgreSQL directory" unless File.realpath(directory) == "/opt/homebrew/var/postgresql@15"
        puts JSON.pretty_generate(snapshot(connection, expected_database: "app_music_development", expected_environment: "development"))
      end
      0
    in ["snapshot-test"]
      require_relative "../lib/isolated_test_database"
      require "uri"
      url = ENV.fetch("APP_MUSIC_TEST_DATABASE_URL")
      PG.connect(url) do |connection|
        puts JSON.pretty_generate(snapshot(connection, expected_database: URI.parse(url).path.delete_prefix("/"), expected_environment: "test"))
      end
      0
    else
      warn "Usage: bundle exec ruby script/migration_reconciliation.rb snapshot-development | snapshot-test | compare-structure EXPECTED.json ACTUAL.json | compare-full EXPECTED.json ACTUAL.json (legacy compare: structure only)"
      2
    end
  rescue MigrationSnapshotComparison::InvalidSnapshot, JSON::ParserError, SystemCallError => error
    warn "Invalid comparison input: #{error.message}"
    2
  end
end

exit MigrationReconciliation.main(ARGV) if $PROGRAM_NAME == __FILE__
