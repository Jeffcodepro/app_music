module Arena
  # One admission window per match. Readiness is an authenticated browser ACK,
  # not an acoustic test. The server owns its deadline and eligible roster.
  class AudioCheck
    SECONDS = 45
    def self.audio?(session)
      session.arena_question_snapshots.where(payload_version: MusicContent::TYPE).where("payload->'stimulus'->>'kind' <> 'visual'").exists?
    end
    def self.required?(session) = session.listening_policy == "sequence-v1" && audio?(session)
    def self.pending?(session) = session.state == "lobby_locked" && session.audio_check_id.present?
    def self.members(session) = session.arena_memberships.where(status: "active")
    def self.ready?(session)
      return session.host_audio_ready_at.present? if session.presentation_mode == "presenter"
      members(session).exists? && !members(session).where(audio_ready_at: nil).exists?
    end
    def self.begin!(session, now)
      return if session.audio_check_id
      session.update!(audio_check_id: SecureRandom.uuid, audio_check_started_at: now, audio_check_deadline_at: now + SECONDS)
    end
    def self.confirm!(actor:, session:, check_id:, ready: true)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          policy = SessionPolicy.new(actor,session)
          raise Forbidden unless session.presentation_mode == "presenter" ? policy.control? : policy.participate?
          raise InvalidTransition unless check_id.is_a?(String) && check_id == session.audio_check_id
          now = DatabaseClock.now
          unless ready
            raise InvalidTransition unless pending?(session) && now < session.audio_check_deadline_at
            if session.presentation_mode == "presenter"
              next true unless session.host_audio_ready_at
              session.update!(host_audio_ready_at: nil)
            else
              member = members(session).lock.find_by!(user: actor)
              next true unless member.audio_ready_at
              member.update!(audio_ready_at: nil)
            end
            Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
            next true
          end
          if session.presentation_mode == "presenter"
            next true if session.host_audio_ready_at
            raise InvalidTransition unless pending?(session) && now < session.audio_check_deadline_at
            session.update!(host_audio_ready_at: now)
          else
            member = members(session).lock.find_by!(user: actor)
            next true if member.audio_ready_at
            raise InvalidTransition unless pending?(session) && now < session.audio_check_deadline_at
            member.update!(audio_ready_at: now)
          end
          Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
          true
        end
      end
    end
    # Caller owns the session lock. Membership decisions and first round opening
    # are committed together by Game, so no participant can slip into a round.
    def self.resolve!(session, now)
      return :cancel unless members(session).exists?
      return :waiting unless ready?(session) || now >= session.audio_check_deadline_at
      if session.presentation_mode == "presenter"
        return session.host_audio_ready_at && members(session).exists? ? :start : :cancel
      end
      members(session).where(audio_ready_at: nil).order(:id).lock.each do |member|
        member.update!(status: "removed", audio_excluded_at: now)
      end
      members(session).exists? ? :start : :cancel
    end
    def self.summary(session, actor:)
      return unless pending?(session) && actor&.persisted? && (session.host_id == actor.id || members(session).exists?(user: actor))
      presenter = session.presentation_mode == "presenter"
      host = session.host_id == actor.id
      own = members(session).find_by(user: actor)
      required = presenter ? 1 : members(session).count
      ready = presenter ? (session.host_audio_ready_at ? 1 : 0) : members(session).where.not(audio_ready_at: nil).count
      players = if presenter
        [{ key: "presenter", nickname: "Tela do anfitrião", avatar_id: "owl", ready: session.host_audio_ready_at.present?, you: host }]
      else
        members(session).order(:created_at).map { |member| { key: Digest::SHA256.hexdigest("#{session.id}:#{member.id}").first(20), nickname: member.nickname, avatar_id: member.avatar_id, ready: member.audio_ready_at.present?, you: member.user_id == actor.id } }
      end
      { players: players, id: session.audio_check_id, deadline_at: session.audio_check_deadline_at.iso8601(3), required_count: required, ready_count: ready,
        own_ready: presenter ? session.host_audio_ready_at.present? : own&.audio_ready_at.present?,
        needs_activation: presenter ? host : own.present?, presenter: presenter,
        all_ready: ready.positive? && ready == required }
    end
    def self.excluded?(session, actor)
      return false unless actor&.persisted?
      session.arena_memberships.where(user: actor, status: "removed").where.not(audio_excluded_at: nil).exists?
    end
    def self.exclusion_view(session, actor:)
      raise Forbidden unless excluded?(session,actor)
      { id: session.id, title: session.title, state: session.state, phase: "audio_excluded", departed: true, participant: false,
        host: false, visibility: session.visibility, capacity: session.capacity, sequence: session.event_sequence, version: session.lock_version,
        participant_count: members(session).count, server_now: DatabaseClock.now.iso8601(3), audio_required: false, next_transition_at: nil }
    end
  end
end
