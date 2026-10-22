module Arena
  class Playback
    WARMUP_SECONDS = 10
    ANNOUNCEMENT_SECONDS = 2
    PLAYBACK_MARGIN_SECONDS = 2
    GAP_SECONDS = 2
    def self.sequenced?(session, round) = session.listening_policy == "sequence-v1" && audio?(round)
    def self.slot_seconds(round) = ANNOUNCEMENT_SECONDS + minimum(round) + PLAYBACK_MARGIN_SECONDS + GAP_SECONDS
    def self.cue_at(round, listen) = round.listening_started_at + WARMUP_SECONDS + (listen - 1) * slot_seconds(round)
    def self.ends_at(session, round) = round.listening_started_at + WARMUP_SECONDS + session.listening_repetitions * slot_seconds(round)
    def self.completed(session, round, key)
      (1..session.listening_repetitions).count { |index| round.listening_progress.dig(key, index.to_s, "ready_at").present? }
    end
    def self.eligible?(session, round, membership)
      return true unless sequenced?(session, round)
      key = session.presentation_mode == "presenter" ? "host" : membership.id
      completed(session, round, key) == session.listening_repetitions
    end
    def self.audio?(round) = round.arena_question_snapshot.payload_version == MusicContent::TYPE && round.arena_question_snapshot.payload.dig("stimulus","kind") != "visual"
    def self.required(session)
      session.presentation_mode == "presenter" ? ["host"] : session.arena_memberships.where(status: "active").pluck(:id)
    end
    def self.ready?(session, round)
      keys = required(session)
      keys.any? && keys.all? { |key| sequenced?(session, round) ? completed(session, round, key) == session.listening_repetitions : round.playbacks.dig(key,"ready_at").present? }
    end
    def self.summary(session, round, actor:)
      key = key_for!(session,actor) rescue nil
      keys = required(session)
      if sequenced?(session, round)
        now = DatabaseClock.now
        count = session.listening_repetitions
        own = key ? completed(session, round, key) : 0
        slots = (1..count).map { |index| { listen: index, cue_at: cue_at(round,index).iso8601(3), play_at: (cue_at(round,index) + ANNOUNCEMENT_SECONDS).iso8601(3), cutoff_at: (cue_at(round,index) + ANNOUNCEMENT_SECONDS + PLAYBACK_MARGIN_SECONDS).iso8601(3), completed: key.present? && round.listening_progress.dig(key,index.to_s,"ready_at").present? } }
        return { generation: round.playback_generation, policy: "sequence-v1", repetitions: count, completed: own,
          can_play: key.present? && session.state == "live" && round.state == "ready" && round.answer_open_at.nil? && now < ends_at(session, round),
          own_ready: own == count, presenter: session.presentation_mode == "presenter", slots: slots, ends_at: ends_at(session,round).iso8601(3) }
      end
      { generation: round.playback_generation, required_count: keys.size, ready_count: keys.count { |id| round.playbacks.dig(id,"ready_at").present? },
        can_play: key.present? && session.state == "live" && %w[ready answering].include?(round.state), own_ready: key.present? && round.playbacks.dig(key,"ready_at").present?,
        presenter: session.presentation_mode == "presenter" }
    end
    def self.start!(actor:, round:, generation:, listen: nil)
      mutate(actor,round,generation) do |session, current, key, now|
        if sequenced?(session, current)
          validate_slot!(session, current, listen)
          raise InvalidTransition unless current.state == "ready" && current.answer_open_at.nil?
          start = cue_at(current, listen) + ANNOUNCEMENT_SECONDS
          raise InvalidTransition unless now >= start && now < start + PLAYBACK_MARGIN_SECONDS
          raise InvalidTransition if current.listening_progress.dig(key,listen.to_s,"ready_at")
          existing = current.playbacks[key]
          if existing && existing["listen"] == listen
            next { token: existing.fetch("token"), minimum_seconds: minimum(current), replay: false, already_started: true }
          end
          token = SecureRandom.uuid
          current.update!(playbacks: current.playbacks.merge(key => { "token" => token, "listen" => listen, "started_at" => now.iso8601(6) }))
          next { token: token, minimum_seconds: minimum(current), replay: false, already_started: false }
        end
        existing = current.playbacks[key]
        if existing && existing["ready_at"]
          next { replay: true, token: existing.fetch("token"), minimum_seconds: minimum(current) }
        end
        raise InvalidTransition unless current.state == "ready" && current.answer_open_at.nil?
        token = SecureRandom.uuid
        current.update!(playbacks: current.playbacks.merge(key => { "token" => token, "started_at" => now.iso8601(6) }))
        { token: token, minimum_seconds: minimum(current), replay: false }
      end
    end
    def self.complete!(actor:, round:, token:, generation:, listen: nil)
      mutate(actor,round,generation) do |session, current, key, now|
        receipt = current.playbacks[key]
        raise InvalidTransition unless receipt && receipt["token"] == token && token.is_a?(String)
        if sequenced?(session, current)
          validate_slot!(session, current, listen)
          raise InvalidTransition unless receipt["listen"] == listen
          next true if current.listening_progress.dig(key,listen.to_s,"ready_at")
          raise InvalidTransition unless current.state == "ready" && current.answer_open_at.nil? && now < cue_at(current,listen) + slot_seconds(current) && now - Time.iso8601(receipt.fetch("started_at")) >= minimum(current)
          history = current.listening_progress.fetch(key, {}).merge(listen.to_s => { "ready_at" => now.iso8601(6) })
          current.update!(listening_progress: current.listening_progress.merge(key => history))
          Events.append!(session: session, round: current, actor: actor, kind: "round_state_changed", payload: { "state" => current.state })
          next true
        end
        next true if receipt["ready_at"]
        raise InvalidTransition unless current.state == "ready" && now - Time.iso8601(receipt.fetch("started_at")) >= minimum(current)
        current.update!(playbacks: current.playbacks.merge(key => receipt.merge("ready_at" => now.iso8601(6))))
        Events.append!(session: session, round: current, actor: actor, kind: "round_state_changed", payload: { "state" => current.state })
        true
      end
    end
    def self.validate_slot!(session, round, listen)
      raise InvalidTransition unless listen.is_a?(Integer) && (1..session.listening_repetitions).cover?(listen) && round.listening_started_at
    end
    private_class_method :validate_slot!
    def self.minimum(round) = round.arena_question_snapshot.payload.fetch("stimulus").fetch("minimum_seconds")
    def self.key_for!(session, actor)
      raise Forbidden unless actor&.persisted?
      if session.presentation_mode == "presenter"
        raise Forbidden unless SessionPolicy.new(actor,session).control?
        "host"
      else
        session.arena_memberships.find_by!(user: actor, status: "active").id
      end
    end
    def self.mutate(actor, round, generation)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session = ArenaSession.find(round.arena_session_id)
        session.with_lock do
          current = session.arena_rounds.lock.find(round.id)
          key = key_for!(session,actor)
          raise InvalidTransition unless audio?(current) && session.state == "live" && %w[ready answering].include?(current.state) && generation.is_a?(Integer) && generation == current.playback_generation
          yield session, current, key, DatabaseClock.now
        end
      end
    end
    private_class_method :key_for!, :mutate
  end
end
