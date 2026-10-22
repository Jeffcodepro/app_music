module Arena
  class Join
    def self.call(actor:, nickname:, code: nil, public_session_id: nil, avatar_id: "owl")
      SchemaIntegrity.verify!
      raise Forbidden, "Authentication required" unless actor&.persisted?
      public_entry = public_session_id.present?
      raise Unavailable, "Convite indisponível ou apelido inválido." unless public_entry || Invites.normalize(code)
      avatar = Avatars.validate!(avatar_id)
      normalized = Nickname.normalize!(nickname)
      actor.with_lock do
        session = public_entry ? ArenaSession.lock.find_by(id: public_session_id, visibility: "public") : ArenaSession.lock.find_by(invite_digest: Invites.digest(code))
        raise Unavailable, "Convite indisponível ou apelido inválido." unless session
        existing = session.arena_memberships.find_by(user: actor, status: "active")
        next existing if existing
        unless session.host_id != actor.id && session.host_ready? && session.state == "lobby_open" && session.invite_expires_at && DatabaseClock.now < session.invite_expires_at && session.arena_memberships.where(status: "active").count < session.capacity && !session.arena_memberships.exists?(user: actor)
          raise Unavailable, "A sala lotou, começou ou não está disponível para sua entrada. Confira o convite ou escolha outra sala."
        end
        membership = ArenaMembership.create!(arena_session: session, user: actor, nickname: normalized, avatar_id: avatar)
        Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
        membership
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      raise Unavailable, "Convite indisponível ou apelido inválido."
    end
  end
end
