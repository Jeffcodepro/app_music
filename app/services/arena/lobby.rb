module Arena
  class Lobby
    def self.leave!(actor:, session:)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          raise InvalidTransition, "O anfitrião deve encerrar o jogo antes de sair." if SessionPolicy.new(actor, session).control?
          member = session.arena_memberships.find_by(user: actor)
          raise Forbidden unless member && %w[active left].include?(member.status)
          next member if member.status == "left"
          member.update!(status: "left")
          Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
          member
        end
      end
    end

    def self.remove!(actor:, session:, membership_id:, expected_version:)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          raise Forbidden unless SessionPolicy.new(actor, session).control?
          raise Conflict, "A sala mudou. Confira os participantes e tente novamente." unless expected_version == session.lock_version
          raise InvalidTransition, "Só é possível remover no lobby." unless %w[lobby_open lobby_locked].include?(session.state)
          member = session.arena_memberships.lock.find(membership_id)
          raise InvalidTransition, "O anfitrião participa desta sala." if member.user_id == actor.id
          next member if member.status == "removed"
          member.update!(status: "removed")
          Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
          member
        end
      end
    end
  end
end
