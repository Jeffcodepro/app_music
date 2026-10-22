module Arena
  # A preparation permission is stored only in the encrypted Rails session.
  # It never authorizes answers, the scoreboard, or private game projections.
  class LobbyAccess
    TTL = 30.minutes

    def self.prepare!(actor:, code: nil, public_session_id: nil)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      room = if public_session_id.present?
        ArenaSession.find_by(id: public_session_id, visibility: "public")
      elsif Invites.normalize(code)
        ArenaSession.find_by(invite_digest: Invites.digest(code))
      end
      raise Unavailable, "Convite ou sala indisponível." unless room
      return [room,nil] if SessionPolicy.new(actor, room).control? || SessionPolicy.new(actor, room).participate?
      now = DatabaseClock.now
      raise Unavailable, "Esta sala não está disponível para entrada." unless available?(room, now) && !room.arena_memberships.exists?(user: actor)
      expires = [now + TTL, room.invite_expires_at].min
      [room,{ "user_id" => actor.id, "room_id" => room.id, "invite_digest" => room.invite_digest, "expires_at" => expires.to_i }]
    end

    def self.view!(actor:, session:, grant:)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      room = ArenaSession.find(session.id)
      owner = SessionPolicy.new(actor, room).control?
      unless owner && room.party? && room.state == "lobby_open"
        validate_grant!(actor, room, grant, DatabaseClock.now)
        raise Forbidden if room.arena_memberships.exists?(user: actor, status: "removed")
      end
      result = { id: room.id, title: room.title, state: room.state, visibility: room.visibility, host: owner,
        identity_required: true, participant: false, participant_count: room.arena_memberships.where(status: "active").count,
        capacity: room.capacity }
      result[:version] = room.lock_version if owner
      result
    end

    def self.confirm!(actor:, session:, grant:, nickname:, avatar_id:)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          existing = session.arena_memberships.find_by(user: actor)
          next existing if existing&.status == "active"
          raise Unavailable, "Sua participação nesta sala foi encerrada." if existing
          owner = SessionPolicy.new(actor, session).control?
          now = DatabaseClock.now
          if owner
            raise Forbidden unless session.party?
            raise InvalidTransition, "O lobby já foi encerrado." unless session.state == "lobby_open"
          else
            validate_grant!(actor, session, grant, now)
          end
          raise Unavailable, "A sala ficou cheia. Escolha outra sala para jogar." if session.arena_memberships.where(status: "active").count >= session.capacity
          member = ArenaMembership.create!(arena_session: session, user: actor, nickname: Nickname.normalize!(nickname), avatar_id: Avatars.validate!(avatar_id))
          Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
          member
        end
      end
    end

    def self.available?(room, now)
      room.state == "lobby_open" && room.host_ready? && room.invite_expires_at && now < room.invite_expires_at &&
        room.arena_memberships.where(status: "active").count < room.capacity
    end

    def self.validate_grant!(actor, room, grant, now)
      valid = grant.is_a?(Hash) && grant["user_id"] == actor.id && grant["room_id"] == room.id &&
        grant["invite_digest"].is_a?(String) && room.invite_digest.present? &&
        ActiveSupport::SecurityUtils.secure_compare(grant["invite_digest"],room.invite_digest) &&
        grant["expires_at"].is_a?(Integer) && now.to_f < grant["expires_at"] &&
        room.state == "lobby_open" && room.host_ready? && room.invite_expires_at && now < room.invite_expires_at
      raise Forbidden unless valid
    end
    private_class_method :available?, :validate_grant!
  end
end
