require "uri"
require "tempfile"
require_relative "manifest"
require_relative "destination"

module ArenaBaseline
  # Scoped to this process/connection. A concurrent CREATE must fail, never DROP.
  module NonDestructiveSchema
    def create_table(name, **options, &block)
      unless @arena_baseline_tables.include?(name.to_s) && !options[:if_not_exists]
        raise UnsafeDestination, "Unexpected baseline table or permissive creation"
      end
      super(name, **options.merge(force: nil, if_not_exists: false), &block)
    end

    def drop_table(*) = raise(UnsafeDestination, "Destructive schema operation refused")
    def drop_schema(*) = raise(UnsafeDestination, "Destructive schema operation refused")
    def truncate_tables(*) = raise(UnsafeDestination, "Destructive schema operation refused")
  end

  class Bootstrap
    def self.call(manifest:, after_empty_check: nil, &before_commit)
      new(manifest).call(after_empty_check:, &before_commit)
    end

    def initialize(manifest)
      @manifest = manifest.verify!(execution: true)
      @uri = URI.parse(ENV.fetch("APP_MUSIC_TEST_DATABASE_URL"))
      @query = URI.decode_www_form(@uri.query).to_h
    end

    def call(after_empty_check: nil)
      raise UnsafeDestination, "Only explicit test environment is allowed" unless Rails.env.test? && ENV["DATABASE_URL"] == ENV["APP_MUSIC_TEST_DATABASE_URL"]
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        verify_identity!(connection)
        paths = connection.migration_context.migrations_paths.map { |path| File.realpath(File.expand_path(path, @manifest.root)) }
        raise UnsafeDestination, "Unexpected migrations_paths" unless paths == [File.realpath(File.join(@manifest.root, "db/migrate"))]
        connection.schema_search_path = "public"
        connection.transaction(requires_new: true, joinable: false) do
          connection.execute("SET LOCAL statement_timeout = '30s'")
          connection.execute("SET LOCAL lock_timeout = '3s'")
          verify_empty!(connection)
          after_empty_check&.call(connection)
          allowed = @manifest.table_names + %w[schema_migrations ar_internal_metadata]
          connection.instance_variable_set(:@arena_baseline_tables, allowed)
          connection.singleton_class.prepend(NonDestructiveSchema)
          Tempfile.create(["arena-baseline-", ".rb"], @query.fetch("host")) do |file|
            file.write(@manifest.schema)
            file.flush
            file.chmod(0o400)
            ActiveRecord::Schema.verbose = false
            ActiveRecord::Tasks::DatabaseTasks.load_schema(ActiveRecord::Base.connection_db_config, :ruby, file.path)
          end
          yield connection if block_given?
          verify_loaded!(connection)
        end
        { baseline_id: @manifest.data.fetch("baseline_id"), database: @uri.path.delete_prefix("/"),
          tables: @manifest.table_names.size + 2, versions: @manifest.versions, historical_ruby_executed: false }
      end
    end

    private

    def verify_identity!(connection)
      actual = connection.select_one(<<~SQL)
        SELECT current_database() AS database, current_user AS role,
          current_setting('data_directory') AS directory, current_setting('port') AS port,
          current_setting('listen_addresses') AS listeners, inet_server_addr()::text AS tcp
      SQL
      safe = actual.fetch("database") == @uri.path.delete_prefix("/") && actual.fetch("role") == @query.fetch("user") &&
        actual.fetch("port") == @query.fetch("port") && actual.fetch("listeners").empty? && actual["tcp"].nil? &&
        File.realpath(actual.fetch("directory")) == File.realpath(File.join(@query.fetch("host"), "data"))
      raise UnsafeDestination, "Connection does not match the verified private test cluster" unless safe
    end

    def verify_empty!(connection)
      Destination.verify_empty!(rows: ->(sql) { connection.select_rows(sql) })
    end

    def verify_loaded!(connection)
      tables = connection.select_values("SELECT tablename FROM pg_tables WHERE schemaname='public'").sort
      expected = (@manifest.table_names + %w[schema_migrations ar_internal_metadata]).sort
      raise UnsafeDestination, "Unexpected baseline tables" unless tables == expected
      versions = connection.select_values("SELECT version FROM schema_migrations ORDER BY version")
      metadata = connection.select_rows("SELECT key,value FROM ar_internal_metadata").to_h
      raise UnsafeDestination, "Unexpected bootstrap versions" unless versions == @manifest.versions
      unless metadata["environment"] == "test" && metadata["schema_sha1"] == Digest::SHA1.hexdigest(@manifest.schema)
        raise UnsafeDestination, "Unexpected bootstrap metadata"
      end
      expected_fks = @manifest.schema.scan(/^  add_foreign_key /).size
      count = connection.select_value("SELECT count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid=k.connamespace WHERE n.nspname='public' AND k.contype='f' AND k.convalidated").to_i
      raise UnsafeDestination, "Unexpected baseline foreign keys" unless count == expected_fks
      @manifest.table_names.each do |table|
        if connection.select_value("SELECT EXISTS (SELECT 1 FROM #{connection.quote_table_name(table)} LIMIT 1)")
          raise UnsafeDestination, "Bootstrap unexpectedly inserted application data"
        end
      end
    end
  end
end
