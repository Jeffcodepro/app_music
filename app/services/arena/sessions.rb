module Arena
  class Sessions
    MAX_IN_PROGRESS = 2

    # Caller holds the owner's lock, shared by all starts and room commands.
    def self.check_start_capacity!(actor:, session:)
      others = ArenaSession.where(host: actor, state: ArenaSession::IN_PROGRESS).where.not(id: session.id)
      if others.count >= MAX_IN_PROGRESS
        raise Unavailable, "Você já tem #{MAX_IN_PROGRESS} partidas em andamento. Encerre uma delas em Suas salas abertas antes de iniciar outra."
      end
    end

    def self.create!(actor:, title:, experience: "facilitated", visibility: "private", capacity: 40, presentation_mode: "legacy", listening_policy: "manual-v1", listening_repetitions: 3, scoring_version: Scoring::LEGACY, arena_content_version: nil, duration_seconds: nil, invite_attributes: {})
      SchemaIntegrity.verify!
      raise Forbidden, "Authentication required" unless actor&.persisted?
      actor.with_lock do
        raise Forbidden, "Registered account required" unless SessionPolicy.new(actor).create?
        session = ArenaSession.create!(host: actor, title: title, experience: experience, visibility: visibility, capacity: capacity,
          scoring_version: scoring_version, presentation_mode: presentation_mode, listening_policy: listening_policy, listening_repetitions: listening_repetitions, arena_content_version: arena_content_version, duration_seconds: duration_seconds, **invite_attributes)
        Events.append!(session: session, actor: actor, kind: "session_created", payload: { "state" => session.state })
        session
      end
    end

    def self.transition!(actor:, session:, to:, expected_version:)
      SchemaIntegrity.verify!
      raise Forbidden, "Authentication required" unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          raise Forbidden, "Session owner required" unless SessionPolicy.new(actor, session).control?
          raise Conflict, "Stale session version" unless expected_version.is_a?(Integer) && expected_version == session.lock_version
          allowed = ArenaSession::TRANSITIONS.fetch(session.state, []).include?(to)
          allowed &&= to == "cancelled" || to == session.resume_from if session.state == "interrupted"
          raise InvalidTransition, "Invalid session transition" unless allowed
          check_start_capacity!(actor: actor, session: session) if %w[lobby_locked live].include?(to)
          coordinating = %w[paused interrupted completed cancelled].include?(to) || %w[paused interrupted].include?(session.state)
          if coordinating && session.arena_rounds.where(state: %w[preparing ready answering paused]).exists?
            raise InvalidTransition, "Active-round coordination belongs to the round engine; no partial transition is allowed"
          end
          if to == "live" && !session.arena_rounds.exists?
            raise InvalidTransition, "A session requires a snapshot-backed round"
          end
          session.state = to
          Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => to })
          session
        end
      end
    end
  end
end
