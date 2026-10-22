module ArenaBaseline
  class UnsafeDestination < StandardError; end

  class Destination
    OBJECTS = <<~SQL.freeze
      SELECT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public') +
        (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public') +
        (SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public')
    SQL

    def self.verify_empty!(rows:)
      schemas = rows.call("SELECT nspname FROM pg_namespace WHERE nspname NOT IN ('public','information_schema') AND nspname !~ '^pg_'")
      raise UnsafeDestination, "Baseline requires a completely empty dedicated database" unless schemas.empty? && rows.call(OBJECTS).first.first.to_i.zero?
    end
  end
end
