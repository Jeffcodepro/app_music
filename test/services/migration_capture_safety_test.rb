require "test_helper"
require_relative "../../script/migration_reconciliation"

class MigrationCaptureSafetyTest < ActiveSupport::TestCase
  # These catalog fixtures must be committed so the audit's independent,
  # read-only transaction can see them. They use a guarded temporary database
  # and unique names; cleanup removes only the objects each test created.
  test "capture refuses a foreign key whose target is outside public" do
    with_capture_connection do |connection|
      namespace = "capture_cross_#{SecureRandom.hex(8)}"
      child = "capture_child_#{SecureRandom.hex(8)}"
      quoted_schema = connection.quote_ident(namespace)
      quoted_child = connection.quote_ident(child)
      connection.exec("CREATE SCHEMA #{quoted_schema}")
      schema_created = true
      connection.exec("CREATE TABLE #{quoted_schema}.parent (id integer PRIMARY KEY)")
      connection.exec("CREATE TABLE public.#{quoted_child} (parent_id integer REFERENCES #{quoted_schema}.parent(id))")
      child_created = true

      error = assert_raises(MigrationSnapshotComparison::InvalidSnapshot) { capture(connection) }
      assert_match(/unsupported.*foreign key/i, error.message)
      assert_equal PG::PQTRANS_IDLE, connection.transaction_status
    ensure
      connection.exec("DROP TABLE public.#{quoted_child}") if child_created
      if schema_created
        connection.exec("DROP TABLE IF EXISTS #{quoted_schema}.parent")
        connection.exec("DROP SCHEMA #{quoted_schema}")
      end
    end
  end

  test "capture refuses MATCH FULL instead of overlooking partially null references" do
    with_capture_connection do |connection|
      parent = "capture_parent_#{SecureRandom.hex(8)}"
      child = "capture_child_#{SecureRandom.hex(8)}"
      quoted_parent = connection.quote_ident(parent)
      quoted_child = connection.quote_ident(child)
      connection.exec("CREATE TABLE public.#{quoted_parent} (a integer, b integer, PRIMARY KEY (a, b))")
      parent_created = true
      connection.exec("CREATE TABLE public.#{quoted_child} (a integer, b integer)")
      child_created = true
      connection.exec("INSERT INTO public.#{quoted_child} (a, b) VALUES (1, NULL)")
      connection.exec(<<~SQL)
        ALTER TABLE public.#{quoted_child} ADD CONSTRAINT capture_match_full
        FOREIGN KEY (a, b) REFERENCES public.#{quoted_parent}(a, b) MATCH FULL NOT VALID
      SQL

      error = assert_raises(MigrationSnapshotComparison::InvalidSnapshot) { capture(connection) }
      assert_match(/unsupported.*foreign key/i, error.message)
      assert_equal PG::PQTRANS_IDLE, connection.transaction_status
    ensure
      connection.exec("DROP TABLE public.#{quoted_child}") if child_created
      connection.exec("DROP TABLE public.#{quoted_parent}") if parent_created
    end
  end

  test "capture fails when row level security would hide records" do
    with_capture_connection do |connection|
      table = "capture_rls_#{SecureRandom.hex(8)}"
      role = "capture_reader_#{SecureRandom.hex(8)}"
      quoted_table = connection.quote_ident(table)
      quoted_role = connection.quote_ident(role)
      connection.exec("CREATE TABLE public.#{quoted_table} (id integer PRIMARY KEY)")
      table_created = true
      connection.exec("INSERT INTO public.#{quoted_table} (id) VALUES (1)")
      connection.exec("ALTER TABLE public.#{quoted_table} ENABLE ROW LEVEL SECURITY")
      connection.exec("CREATE POLICY capture_deny ON public.#{quoted_table} FOR SELECT USING (false)")
      connection.exec("CREATE ROLE #{quoted_role} NOLOGIN NOSUPERUSER NOBYPASSRLS")
      role_created = true
      # Membership belongs only to this temporary role; existing table ACLs
      # remain untouched. pg_read_all_data deliberately does not bypass RLS.
      connection.exec("GRANT pg_read_all_data, pg_read_all_settings TO #{quoted_role}")
      connection.exec("SET ROLE #{quoted_role}")
      assert_equal "0", connection.exec("SELECT count(*) FROM public.#{quoted_table}").getvalue(0, 0)

      error = assert_raises(PG::InsufficientPrivilege) { capture(connection) }
      assert_match(/row.level security/i, error.message)
      assert_equal PG::PQTRANS_IDLE, connection.transaction_status
    ensure
      connection.exec("RESET ROLE") unless connection.finished?
      connection.exec("DROP TABLE public.#{quoted_table}") if table_created
      connection.exec("DROP ROLE #{quoted_role}") if role_created
    end
  end

  private

  def with_capture_connection
    connection = PG.connect(ENV.fetch("APP_MUSIC_TEST_DATABASE_URL"))
    yield connection
  ensure
    connection&.close unless connection&.finished?
  end

  def capture(connection)
    MigrationReconciliation.snapshot(connection, expected_database: connection.db, expected_environment: "test")
  end
end
