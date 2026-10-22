require "uri"

# Names alone do not attest isolation. Verify the actual server's private data
# directory and disabled TCP listener. Accept another auditor's private scratch.
url = ENV.fetch("APP_MUSIC_TEST_DATABASE_URL") { abort "Use bin/test-isolated with APP_MUSIC_TEST_DATABASE_URL." }
begin
  uri = URI.parse(url)
  pairs = URI.decode_www_form(uri.query.to_s)
  query = pairs.to_h
  database = uri.path.to_s.delete_prefix("/")
  socket = query.fetch("host", "")
  valid = %w[postgres postgresql].include?(uri.scheme) && uri.host.to_s.empty? && uri.userinfo.nil? &&
          (query.keys - %w[host port user]).empty? && query.size == pairs.size && uri.fragment.nil? &&
          database.match?(/\Aapp_music_(?:m02|integrity)[a-z0-9_]*_test\z/) &&
          query.fetch("port", "").match?(/\A\d{1,5}\z/) && (1..65535).cover?(query["port"].to_i) &&
          query.fetch("user", "").match?(/\A[a-zA-Z0-9_]+\z/) && socket.start_with?("/") &&
          File.directory?(socket) && File.realpath(socket) == socket &&
          File.file?(File.join(socket, "data", "PG_VERSION")) &&
          File.realpath(File.join(socket, "data")) == File.join(socket, "data") &&
          [socket, File.join(socket, "data")].all? { |path| File.stat(path).uid == Process.uid && (File.stat(path).mode & 0o077).zero? }
  abort "Refusing tests: use a private dedicated PostgreSQL socket and app_music_integrity*_test database." unless valid
rescue URI::InvalidURIError, ArgumentError, SystemCallError
  abort "Refusing tests: invalid isolated database configuration."
end

# Prevent libpq defaults such as PGHOSTADDR/PGSERVICE from overriding the URL.
# The Rails child inherits this sanitized environment too.
ENV.keys.grep(/\APG/).each { |key| ENV.delete(key) }
require "pg"
PG.connect(url) do |connection|
  actual = connection.exec("SELECT current_database() AS database, current_setting('data_directory') AS directory, current_setting('listen_addresses') AS listeners").first
  unless actual.fetch("database") == database && actual.fetch("listeners").empty? &&
         File.realpath(actual.fetch("directory")) == File.realpath(File.join(socket, "data"))
    abort "Refusing tests: PostgreSQL is not the dedicated temporary cluster without TCP."
  end
end
warn "Isolated test database: #{database} (#{socket}); RAILS_ENV=test; workers=1"
