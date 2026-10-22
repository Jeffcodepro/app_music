require "json"
require "digest"
require "open3"
require "pathname"

module ArenaBaseline
  class InvalidManifest < StandardError; end

  class Manifest
    MISSING = %w[20260320120000 20260325120000 20260325123000].freeze
    attr_reader :data, :root

    def initialize(root:, repository: root)
      @root = File.realpath(root)
      @repository = File.realpath(repository)
    end

    def verify!(execution: false)
      @data = JSON.parse(File.read(File.join(root, "docs/arena/baseline-manifest.json")), allow_duplicate_key: false)
      check(data.fetch("manifest_version") == 1 && data.fetch("baseline_id") == "appmusic-pre-arena-20261020")
      check(data.fetch("source_commit").match?(/\A[0-9a-f]{40}\z/))
      check(data.fetch("schema").fetch("path") == "db/schema.rb")
      check(data.fetch("migration_paths") == ["db/migrate"])
      if execution
        check(data.fetch("execution_authorized") == true &&
          data.fetch("execution_scope") == "verified_disposable_test_database_only")
      end
      @schema = git_read("db/schema.rb")
      blob, status = Open3.capture2("git", "rev-parse", "#{data.fetch('source_commit')}:db/schema.rb", chdir: @repository, err: File::NULL)
      check(status.success? && blob.strip == data.fetch("schema").fetch("git_blob"))
      check(Digest::SHA256.hexdigest(schema) == data.fetch("schema").fetch("sha256"))
      declared = schema.match(/define\(version: ([\d_]+)\)/)&.captures&.first&.delete("_")
      check(declared == cutoff && cutoff == data.fetch("future_migrations_must_be_newer_than"))
      check(schema.scan(/^  create_table "([^"]+)"/).flatten == table_names)
      entries = data.fetch("available_migrations")
      check(entries.size == 9 && entries.map { |entry| entry.fetch("version") } == versions)
      check(versions == versions.sort.uniq && versions.all? { |version| version.match?(/\A\d{14}\z/) && version <= cutoff })
      historical = Dir.glob(File.join(root, "db/migrate/*.rb")).select { |path| File.basename(path).split("_", 2).first <= cutoff }
      check(historical.map { |path| relative(path) }.sort == entries.map { |entry| entry.fetch("path") }.sort)
      entries.each do |entry|
        path = entry.fetch("path")
        check(path.match?(/\Adb\/migrate\/\d{14}_[a-z0-9_.]+\.rb\z/) && File.basename(path).start_with?(entry.fetch("version") + "_"))
        full_path = File.realpath(File.join(root, path))
        check(full_path.start_with?(root + "/db/migrate/"))
        expected = entry.fetch("sha256")
        check(Digest::SHA256.hexdigest(File.binread(full_path)) == expected)
        check(Digest::SHA256.hexdigest(git_read(path)) == expected)
      end
      missing = data.fetch("missing_original_migrations").map { |entry| entry.fetch("version") }
      check(missing.sort == MISSING && (missing & versions).empty?)
      self
    rescue KeyError, JSON::ParserError, SystemCallError, TypeError, NoMethodError => error
      raise InvalidManifest, "Invalid baseline manifest (#{error.class})"
    end

    def schema = @schema || raise(InvalidManifest, "Verify the manifest first")
    def versions = data.fetch("expected_bootstrap_migration_versions")
    def cutoff = data.fetch("schema").fetch("declared_version")
    def table_names = data.fetch("schema").fetch("declared_tables")

    private

    def git_read(path)
      output, status = Open3.capture2("git", "show", "#{data.fetch('source_commit')}:#{path}", chdir: @repository, err: File::NULL)
      check(status.success?)
      output
    end

    def relative(path) = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
    def check(condition) = condition || raise(InvalidManifest, "Baseline source, approval or historical migrations differ from the reviewed manifest")
  end
end
