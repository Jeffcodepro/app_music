module Arena
  # Trusted operator/console only. No route or Devise parameter grants access.
  class HostAccess
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    def self.grant!(user:, operator_reference:)
      SchemaIntegrity.verify!
      raise ArgumentError, "An opaque administrative UUID is required" unless UUID.match?(operator_reference.to_s)
      user.with_lock do
        ArenaHostGrant.create!(user: user, operator_reference: operator_reference, granted_at: Time.current)
      end
    end

    def self.revoke!(grant:, operator_reference:)
      SchemaIntegrity.verify!
      raise ArgumentError, "An opaque administrative UUID is required" unless UUID.match?(operator_reference.to_s)
      user = grant.user || raise(Forbidden, "Account no longer exists")
      user.with_lock do
        grant.lock!
        grant.update!(revoked_at: Time.current, revocation_reference: operator_reference) unless grant.revoked_at
      end
      grant
    end
  end
end
