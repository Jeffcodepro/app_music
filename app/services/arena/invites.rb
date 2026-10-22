require "uri"

module Arena
  class Invites
    def self.encryptor
      key = Rails.application.key_generator.generate_key("arena-private-invite-v1", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end

    def self.attributes(now:)
      code = SecureRandom.alphanumeric(16).upcase
      { invite_digest: digest(code), invite_ciphertext: encryptor.encrypt_and_sign(code), invite_expires_at: now + 2.hours }
    end

    def self.digest(code)
      key = Rails.application.key_generator.generate_key("arena-invite-lookup-v1", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, normalize(code).to_s)
    end

    def self.normalize(input)
      text = input.to_s
      return if text.bytesize > 2048 || !text.valid_encoding?
      text = text.unicode_normalize(:nfkc).strip
      if text.match?(/\Ahttps?:\/\//i)
        uri = URI.parse(text)
        return unless uri.path == "/app/arena"
        codes = URI.decode_www_form(uri.query.to_s).select { |key, _| key == "code" }
        return unless codes.one?
        text = codes.first.last
      end
      text = text.gsub(/[[:space:]-]/, "").upcase
      text if text.match?(/\A[A-Z0-9]{16}\z/)
    rescue URI::InvalidURIError, ArgumentError
      nil
    end

    def self.owned_session(actor:, code:)
      return unless actor&.persisted? && normalize(code)
      ArenaSession.find_by(host_id: actor.id, invite_digest: digest(code))
    end

    def self.code(session)
      encryptor.decrypt_and_verify(session.invite_ciphertext)
    end
  end
end
