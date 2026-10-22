require "json"

# Pure file comparison. No Rails boot, database connection or writes.
module MigrationSnapshotComparison
  class InvalidSnapshot < ArgumentError; end

  STATE_CATEGORIES = %w[structure migrations records foreign_keys sequence_state].freeze
  SNAPSHOT_FIELDS = ["identity", *STATE_CATEGORIES].freeze
  IDENTITY_FIELDS = {
    "database" => :text, "role" => :text, "data_directory" => :text,
    "port" => :count_text, "server_version" => :text, "read_only" => :text,
    "tcp_address" => :nullable_text, "rails_environment" => :text
  }.freeze
  STRUCTURE_FIELDS = {
    "tables" => { "kind" => :text, "persistence" => :text, "row_security" => :pg_bool, "force_row_security" => :pg_bool },
    "columns" => { "type" => :text, "not_null" => :pg_bool, "default_expression" => :nullable_text,
                   "identity" => :string, "generated" => :string, "collation" => :nullable_text },
    "indexes" => { "table_name" => :text, "definition" => :text, "valid" => :pg_bool, "ready" => :pg_bool },
    "constraints" => { "type" => :text, "definition" => :text, "validated" => :pg_bool, "deferrable" => :pg_bool, "deferred" => :pg_bool },
    "sequences" => { "type" => :text, "start" => :integer_text, "increment" => :integer_text,
                     "maximum" => :integer_text, "minimum" => :integer_text, "cache" => :count_text,
                     "cycle" => :pg_bool, "owned_table" => :nullable_text, "owned_column" => :nullable_text },
    "views" => { "kind" => :text, "definition" => :text },
    "triggers" => { "definition" => :text, "enabled" => :text },
    "routines" => { "definition" => :text }, "enums" => { "label" => :string },
    "extensions" => { "version" => :text }
  }.freeze
  RECORD_FIELDS = { "count" => :count_text, "fingerprint" => :fingerprint }.freeze
  SEQUENCE_FIELDS = { "last_value" => :integer_text, "is_called" => :pg_bool }.freeze
  FOREIGN_KEY_FIELDS = { "source" => :text, "target" => :text, "constraint" => :text, "orphans" => :count }.freeze

  def self.read(path)
    # Supported by the locked json 2.19.1 and Ruby's json 3.x. Reject duplicate
    # keys during parsing, before a Hash can silently overwrite their values.
    JSON.parse(File.read(path), allow_duplicate_key: false)
  end

  def self.compare(expected, actual, scope:)
    raise ArgumentError, "Unknown comparison scope" unless %w[structure full].include?(scope)
    validate!(expected, "expected")
    validate!(actual, "actual")
    changes = STRUCTURE_FIELDS.keys.flat_map do |subcategory|
      differences(expected.fetch("structure").fetch(subcategory), actual.fetch("structure").fetch(subcategory),
                  category: "structure", subcategory:)
    end
    categories = scope == "full" ? STATE_CATEGORIES : ["structure"]
    if scope == "full"
      %w[migrations records foreign_keys sequence_state].each do |category|
        left, right = [expected, actual].map { |snapshot| indexed(snapshot.fetch(category), category) }
        changes.concat(differences(left, right, category:))
      end
    end
    result = { "scope" => scope, "categories" => categories, "structure_categories" => STRUCTURE_FIELDS.keys,
               "identity_compared" => false, "equal" => changes.empty?, "differences" => changes }
    if scope == "full"
      counts = [expected, actual].map { |snapshot| snapshot.fetch("foreign_keys").sum { |fk| fk.fetch("orphans") } }
      result["referential_integrity"] = { "expected_orphans" => counts[0], "actual_orphans" => counts[1], "healthy" => counts.all?(&:zero?) }
    end
    result
  end

  def self.validate!(snapshot, path = "snapshot")
    exact_keys!(snapshot, SNAPSHOT_FIELDS, path)
    fields!(snapshot.fetch("identity"), IDENTITY_FIELDS, "#{path}.identity")
    identity = snapshot.fetch("identity")
    check!(identity.fetch("read_only") == "on" && identity.fetch("tcp_address").nil?, "#{path}.identity", "expected a read-only Unix socket capture")
    check!((1..65535).cover?(identity.fetch("port").to_i), "#{path}.identity.port", "invalid port")
    structure = snapshot.fetch("structure")
    exact_keys!(structure, STRUCTURE_FIELDS.keys, "#{path}.structure")
    STRUCTURE_FIELDS.each do |category, fields|
      map!(structure.fetch(category), "#{path}.structure.#{category}") do |name, entry|
        fields!(entry, fields, "#{path}.structure.#{category}.#{name}")
      end
    end
    migrations = snapshot.fetch("migrations")
    check!(migrations.is_a?(Array) && migrations.all? { |value| value.is_a?(String) && /\A\d+\z/.match?(value) }, "#{path}.migrations", "expected decimal version strings")
    check!(migrations.uniq.size == migrations.size, "#{path}.migrations", "duplicate versions")
    map!(snapshot.fetch("records"), "#{path}.records") { |name, row| fields!(row, RECORD_FIELDS, "#{path}.records.#{name}") }
    exact_keys!(snapshot.fetch("records"), structure.fetch("tables").keys, "#{path}.records")
    map!(snapshot.fetch("sequence_state"), "#{path}.sequence_state") { |name, row| fields!(row, SEQUENCE_FIELDS, "#{path}.sequence_state.#{name}") }
    exact_keys!(snapshot.fetch("sequence_state"), structure.fetch("sequences").keys, "#{path}.sequence_state")
    foreign_keys = snapshot.fetch("foreign_keys")
    check!(foreign_keys.is_a?(Array), "#{path}.foreign_keys", "expected array")
    foreign_keys.each_with_index do |fk, index|
      fields!(fk, FOREIGN_KEY_FIELDS, "#{path}.foreign_keys[#{index}]")
      check!(structure.fetch("tables").key?(fk.fetch("source")) && structure.fetch("tables").key?(fk.fetch("target")), "#{path}.foreign_keys[#{index}]", "unknown source or target table")
    end
    keys = foreign_keys.map { |fk| "#{fk.fetch('source')}.#{fk.fetch('constraint')}" }
    check!(keys.uniq.size == keys.size, "#{path}.foreign_keys", "duplicate constraints")
    expected_keys = structure.fetch("constraints").select { |_name, row| row.fetch("type") == "f" }.keys
    check!(keys.sort == expected_keys.sort, "#{path}.foreign_keys", "coverage differs from structural foreign keys")
    true
  end

  def self.differences(expected, actual, category:, subcategory: nil)
    (expected.keys | actual.keys).sort.filter_map do |name|
      next if expected[name] == actual[name]
      row = { "category" => category, "name" => name,
              "status" => !expected.key?(name) ? "extra" : !actual.key?(name) ? "missing" : "changed",
              "expected" => expected[name], "actual" => actual[name] }
      row["subcategory"] = subcategory if subcategory
      row
    end
  end

  def self.indexed(value, category)
    case category
    when "migrations" then value.to_h { |version| [version, version] }
    when "foreign_keys" then value.to_h { |row| ["#{row.fetch('source')}.#{row.fetch('constraint')}", row] }
    else value
    end
  end

  def self.exact_keys!(object, expected, path)
    check!(object.is_a?(Hash), path, "expected object")
    check!(object.keys.all? { |key| key.is_a?(String) }, path, "expected string field names")
    check!(object.keys.sort == expected.sort, path, "missing or unsupported fields")
  end

  def self.map!(object, path)
    check!(object.is_a?(Hash), path, "expected object")
    object.each do |name, value|
      check!(name.is_a?(String) && !name.empty?, path, "expected nonempty object names")
      yield name, value
    end
  end

  def self.fields!(object, definitions, path)
    exact_keys!(object, definitions.keys, path)
    definitions.each do |name, type|
      value = object.fetch(name)
      valid = case type
              when :text then value.is_a?(String) && !value.empty?
              when :string then value.is_a?(String)
              when :nullable_text then value.nil? || value.is_a?(String)
              when :pg_bool then %w[t f].include?(value)
              when :integer_text then value.is_a?(String) && /\A-?\d+\z/.match?(value)
              when :count_text then value.is_a?(String) && /\A\d+\z/.match?(value)
              when :fingerprint then value.is_a?(String) && /\A[0-9a-f]{32}\z/.match?(value)
              when :count then value.is_a?(Integer) && value >= 0
              end
      check!(valid, "#{path}.#{name}", "invalid #{type}")
    end
  end

  def self.check!(condition, path, message)
    raise InvalidSnapshot, "#{path}: #{message}" unless condition
  end

  private_class_method :differences, :indexed, :exact_keys!, :map!, :fields!, :check!
end
