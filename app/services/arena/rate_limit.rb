require "pg"

module Arena
  class RateLimit
    def self.consume!(scope:, subject:, limit:)
      key = Rails.application.key_generator.generate_key("arena-rate-principal-v1", 32)
      digest = OpenSSL::HMAC.hexdigest("SHA256", key, "#{scope}:#{subject}")
      connection = ActiveRecord::Base.connection
      # Runs before the gameplay transaction: an invalid invitation still costs
      # an attempt. No raw account identifier or IP is persisted in this table.
      sql = <<~SQL
        WITH current_window AS (SELECT date_trunc('minute', clock_timestamp() AT TIME ZONE 'UTC') AS started)
        INSERT INTO public.arena_rate_windows(id,key_digest,window_at,attempts,expires_at)
          SELECT gen_random_uuid(),$1,started,1,started + interval '2 minutes' FROM current_window
        ON CONFLICT (key_digest,window_at) DO UPDATE SET attempts=arena_rate_windows.attempts+1
          WHERE arena_rate_windows.attempts < $2
        RETURNING id
      SQL
      parameters = [digest, Integer(limit)]
      result = if connection.transaction_open?
        # A caller's business rollback must not refund this budget. A short
        # independent libpq connection avoids exhausting the request's pool.
        effective = connection.raw_connection.conninfo_hash.reject { |name, value| name == "service" || value.nil? || value.empty? }
        PG.connect(effective.merge("connect_timeout" => "3")) do |independent|
          independent.exec("SET statement_timeout='3s'; SET lock_timeout='2s'")
          independent.exec_params(sql, parameters)
        end
      else
        # Authenticated requests already lease a connection. Reuse it in
        # autocommit instead of waiting for a second slot in the same pool.
        connection.raw_connection.exec_params(sql, parameters)
      end
      raise RateLimited, "Muitas tentativas. Aguarde um minuto e tente novamente." if result.ntuples.zero?
      true
    end
  end
end
