module Arena
  class Game
    CAPACITY = 40
    COUNTDOWN_SECONDS = 3
    FEEDBACK_SECONDS = 5
    COMMANDS = %w[start close pause resume next end finish explain void renew_invite].freeze

    def self.create!(actor:, content_version:, title:, question_count:, duration_seconds:, technical_preview: false, experience: "facilitated", host_nickname: "Anfitrião", host_avatar: "owl", visibility: "private", capacity: CAPACITY, scoring_version: Scoring::LEGACY, defer_host_identity: false, presentation_mode: "legacy", listening_repetitions: nil)
      SchemaIntegrity.verify!
      raise Forbidden, "Authentication required" unless actor&.persisted?
      preview = technical_preview && (Rails.env.test? || Catalog.technical_preview?)
      count, duration, capacity = [question_count, duration_seconds, capacity].map { |value| Integer(value.to_s, exception: false) }
      raise InvalidContent, "Invalid game configuration" unless count && (1..50).cover?(count) && duration && (10..120).cover?(duration) && capacity && (1..CAPACITY).cover?(capacity) && %w[facilitated party].include?(experience) && %w[private public].include?(visibility) && Scoring::VERSIONS.include?(scoring_version)
      listening_policy = listening_repetitions.nil? ? "manual-v1" : "sequence-v1"
      repetitions = listening_repetitions.nil? ? 3 : Integer(listening_repetitions.to_s, exception: false)
      raise InvalidContent unless repetitions && (1..5).cover?(repetitions)
      musical = content_version.body["type"] == MusicContent::TYPE
      presentation_mode = experience == "party" ? "individual" : "presenter" if musical
      raise InvalidContent unless %w[legacy individual presenter].include?(presentation_mode)
      avatar = Avatars.validate!(host_avatar) if experience == "party" && !defer_host_identity
      nickname = Nickname.normalize!(host_nickname) if experience == "party" && !defer_host_identity
      actor.with_lock do
        content_version = ArenaContentVersion.lock.find(content_version.id)
        unless content_version.published? || (preview && content_version.status == "technical_preview")
          raise InvalidContent, "Only approved content can start a session"
        end
        Catalog.validate!(content_version)
        raise InvalidContent, "Not enough distinct exercises" if !musical && count > content_version.body.fetch("exercises").size
        session = Sessions.create!(actor: actor, title: title, experience: experience, visibility: visibility, capacity: capacity,
          scoring_version: scoring_version, presentation_mode: presentation_mode, listening_policy: listening_policy, listening_repetitions: repetitions, arena_content_version: content_version, duration_seconds: duration, invite_attributes: Invites.attributes(now: DatabaseClock.now))
        random = Random.new(SecureRandom.random_number(2**63))
        entries = musical ? MusicContent.sample(content_version.body.fetch("exercises"), count, random: random) : content_version.body.fetch("exercises").sample(count, random: random)
        entries.each_with_index do |exercise, index|
          adapter = musical ? MusicContent : (content_version.body["type"] == ReadingVisualContent::TYPE ? ReadingVisualContent : ReadingContent)
          snapshot = ArenaQuestionSnapshot.create!(arena_session: session, arena_content_version: content_version,
            payload_version: musical ? MusicContent::TYPE : (adapter == ReadingVisualContent ? ReadingVisualContent::TYPE : "reading-note-v1"), payload: adapter.snapshot(exercise, content_version: content_version, random: random))
          ArenaRound.create!(arena_session: session, arena_question_snapshot: snapshot, position: index + 1)
        end
        ArenaMembership.create!(arena_session: session, user: actor, nickname: nickname, avatar_id: avatar) if session.party? && !defer_host_identity
        session.state = "lobby_open"
        append_session!(session, actor)
        session
      end
    end

    def self.command!(actor:, session:, command:, expected_version:)
      SchemaIntegrity.verify!
      raise Forbidden, "Authentication required" unless actor&.persisted?
      raise InvalidTransition, "Unknown command" unless COMMANDS.include?(command)
      actor.with_lock do
        session.with_lock do
          raise Forbidden, "Session owner required" unless SessionPolicy.new(actor, session).control?
          check_version!(session, expected_version)
          unless %w[finish end].include?(command) || (session.arena_content_version_id && session.duration_seconds)
            raise InvalidContent, "Session has no content configuration"
          end
          now = DatabaseClock.now
          round = current_round(session)
          case command
          when "renew_invite"
            raise InvalidTransition, "Invitations require an open lobby" unless session.state == "lobby_open"
            session.update!(**Invites.attributes(now: now))
            append_session!(session, actor)
          when "start"
            next session if AudioCheck.pending?(session)
            raise InvalidTransition, "Confirme seu personagem e apelido no lobby antes de iniciar." unless session.host_ready?
            raise InvalidTransition, "Lobby unavailable" unless %w[lobby_open lobby_locked].include?(session.state) && session.arena_memberships.where(status: "active").exists?
            Sessions.check_start_capacity!(actor: actor, session: session)
            if session.state == "lobby_open"
              session.state = "lobby_locked"
              append_session!(session, actor)
            end
            if AudioCheck.required?(session)
              AudioCheck.begin!(session, now)
              append_session!(session, actor)
            else
              session.state = "live"
              append_session!(session, actor)
              open_next!(session, actor, now)
            end
          when "close"
            raise InvalidTransition, "No answering round" unless %w[live paused].include?(session.state) && round && (round.state == "answering" || (round.state == "paused" && round.paused_from == "answering"))
            close_round!(session, round, actor, now)
            hold_results!(round) if session.state == "paused"
          when "void"
            raise InvalidTransition unless %w[live paused].include?(session.state) && round && %w[ready answering paused].include?(round.state)
            round.update!(state: "void")
            append_round!(session, round, actor)
          when "explain"
            raise InvalidTransition, "No presented question" unless %w[live paused].include?(session.state) && round && (round.state.in?(%w[answering results]) || (round.state == "paused" && round.paused_from == "answering"))
            close_round!(session, round, actor, now) unless round.state == "results"
            hold_results!(round)
            if session.state == "live"
              session.state = "paused"
              append_session!(session, actor)
            end
          when "pause"
            raise InvalidTransition, "Session is not live" unless session.state == "live"
            if round&.state == "answering"
              if now >= round.deadline_at
                close_round!(session, round, actor, now)
              else
                round.update!(state: "paused", paused_from: "answering", remaining_ms: [((round.deadline_at - now) * 1000).floor, 1].max)
                append_round!(session, round, actor)
              end
            elsif round&.state == "ready"
              attributes = { state: "paused", paused_from: "ready", remaining_ms: round.answer_open_at ? [((round.answer_open_at - now) * 1000).ceil, 0].max : 0 }
              attributes.merge!(playback_generation: round.playback_generation + 1, playbacks: {}) if Playback.audio?(round) && round.answer_open_at.nil?
              round.update!(attributes)
              append_round!(session, round, actor)
            end
            if round&.state == "results" && round.advance_at
              round.update!(remaining_ms: [((round.advance_at - now) * 1000).ceil, 0].max, advance_at: nil)
            end
            session.state = "paused"
            append_session!(session, actor)
          when "resume"
            raise InvalidTransition, "Session is not paused" unless session.state == "paused"
            if round&.state == "paused"
              remaining = round.remaining_ms / 1000.0
              if round.paused_from == "ready"
                opens = (now + remaining unless Playback.audio?(round) && round.answer_open_at.nil?)
                attributes = { state: "ready", answer_open_at: opens, deadline_at: (opens + session.duration_seconds if opens) }
                attributes[:listening_started_at] = now if Playback.sequenced?(session, round) && opens.nil?
                round.update!(attributes)
              else
                raise InvalidTransition, "Invalid remaining time" unless remaining.positive?
                round.update!(state: "answering", answer_open_at: now, deadline_at: now + remaining)
              end
              append_round!(session, round, actor)
            elsif round&.state == "results" && session.party? && round.remaining_ms
              round.update!(advance_at: now + round.remaining_ms / 1000.0, remaining_ms: nil)
            end
            session.state = "live"
            append_session!(session, actor)
          when "next"
            raise InvalidTransition, "Close the current round first" unless %w[live paused].include?(session.state) && round && %w[results void].include?(round.state)
            if session.state == "paused"
              session.state = "live"
              append_session!(session, actor)
            end
            open_next!(session, actor, now)
          when "finish"
            raise InvalidTransition, "Session already ended" if ArenaSession::TERMINAL.include?(session.state)
            if round && (round.state == "answering" || (round.state == "paused" && round.paused_from == "answering"))
              close_round!(session, round, actor, now)
            end
            session.arena_rounds.where.not(state: %w[results closed void]).order(:position).lock.each do |pending|
              pending.update!(state: "void")
              append_round!(session, pending, actor)
            end
            can_complete = ArenaSession::TRANSITIONS.fetch(session.state).include?("completed")
            session.state = can_complete && session.arena_rounds.where(state: "results").exists? ? "completed" : "cancelled"
            append_session!(session, actor)
          when "end"
            raise InvalidTransition, "Session already ended" if ArenaSession::TERMINAL.include?(session.state)
            session.arena_rounds.where.not(state: %w[results closed void]).order(:position).lock.each do |pending|
              pending.update!(state: "void")
              append_round!(session, pending, actor)
            end
            session.state = "cancelled"
            append_session!(session, actor)
          end
          session
        end
      end
    end

    # Every mutation is a POST authorized by membership/ownership, under the
    # same session lock as answers and commands. GET never advances a game.
    def self.settle!(actor:, session:)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          policy = SessionPolicy.new(actor, session)
          raise Forbidden unless policy.control? || policy.participate?
          now = DatabaseClock.now
          if AudioCheck.pending?(session)
            outcome = AudioCheck.resolve!(session, now)
            unless outcome == :waiting
              session.state = outcome == :start ? "live" : "cancelled"
              append_session!(session, nil)
              open_next!(session, nil, now) if outcome == :start
            end
            next session
          end
          next session unless session.state == "live"
          round = current_round(session)
          if round&.state == "ready" && Playback.audio?(round) && round.answer_open_at.nil?
            if Playback.sequenced?(session, round) && now >= Playback.ends_at(session, round)
              if session.presentation_mode == "presenter" && !Playback.ready?(session, round)
                round.update!(state: "void")
              else
                round.update!(answer_open_at: now + COUNTDOWN_SECONDS, deadline_at: now + COUNTDOWN_SECONDS + session.duration_seconds)
              end
              append_round!(session, round, nil)
            elsif !Playback.sequenced?(session, round) && Playback.ready?(session,round)
              round.update!(answer_open_at: now + COUNTDOWN_SECONDS, deadline_at: now + COUNTDOWN_SECONDS + session.duration_seconds)
              append_round!(session, round, nil)
            end
          elsif round&.state == "ready" && round.answer_open_at && now >= round.answer_open_at
            # A returning client gets a full answer window, never a skipped item.
            round.update!(state: "answering", answer_open_at: now, deadline_at: now + session.duration_seconds)
            append_round!(session, round, nil)
          elsif round&.state == "answering" && (now >= round.deadline_at || (session.party? && everyone_answered?(session, round)))
            close_round!(session, round, nil, now)
          elsif session.party? && round&.state == "results" && round.advance_at && now >= round.advance_at
            open_next!(session, nil, now)
          end
          session
        end
      end
    end

    def self.rematch!(actor:, session:, expected_version:)
      SchemaIntegrity.verify!
      raise Forbidden unless actor&.persisted?
      actor.with_lock do
        session.with_lock do
          raise Forbidden unless SessionPolicy.new(actor, session).control?
          raise InvalidTransition unless session.state == "completed"
          next session.rematch_session if session.rematch_session_id
          check_version!(session, expected_version)
          identity = session.arena_memberships.find_by(user: actor, status: "active")
          nickname = identity&.nickname || "Anfitrião"
          new_room = create!(actor: actor, content_version: session.arena_content_version, title: session.title,
            question_count: session.arena_rounds.count, duration_seconds: session.duration_seconds,
            experience: session.experience, host_nickname: nickname, host_avatar: Avatars::CHOICES.key?(identity&.avatar_id) ? identity.avatar_id : "owl",
            visibility: session.visibility, capacity: session.capacity, scoring_version: session.scoring_version, technical_preview: Catalog.technical_preview?,
            listening_repetitions: session.listening_repetitions)
          session.update!(rematch_session: new_room)
          append_session!(session, actor)
          new_room
        end
      end
    end

    def self.current_round(session)
      session.arena_rounds.where.not(state: "queued").order(position: :desc).lock.first
    end

    def self.everyone_answered?(session, round)
      eligible = session.arena_memberships.where(status: "active")
      count = eligible.count
      count.positive? && ArenaAnswer.where(arena_round: round, arena_membership_id: eligible.select(:id)).count == count
    end

    def self.check_version!(session, expected_version)
      raise Conflict, "A sessão mudou; atualize e tente novamente." unless expected_version.is_a?(Integer) && expected_version == session.lock_version
    end

    def self.open_next!(session, actor, now)
      round = session.arena_rounds.where(state: "queued").order(:position).lock.first
      unless round
        session.state = "completed"
        append_session!(session, actor)
        return
      end
      listening = Playback.audio?(round)
      opens = (now + (session.party? ? COUNTDOWN_SECONDS : 0) unless listening)
      round.update!(state: "preparing")
      round.update!(state: "ready", answer_open_at: opens, deadline_at: (opens + session.duration_seconds if opens),
        listening_started_at: (now if listening && session.listening_policy == "sequence-v1"))
      round.update!(state: "answering") unless session.party? || listening
      append_round!(session, round, actor)
    end

    def self.close_round!(session, round, actor, now)
      round.update!(state: "closed")
      round.update!(state: "results", advance_at: (now + FEEDBACK_SECONDS if session.party?), remaining_ms: nil)
      append_round!(session, round, actor)
    end

    def self.hold_results!(round)
      round.update!(advance_at: nil, remaining_ms: FEEDBACK_SECONDS * 1000)
    end

    def self.append_round!(session, round, actor)
      Events.append!(session: session, round: round, actor: actor, kind: "round_state_changed", payload: { "state" => round.state })
    end

    def self.append_session!(session, actor)
      Events.append!(session: session, actor: actor, kind: "session_state_changed", payload: { "state" => session.state })
    end
    private_class_method :current_round, :everyone_answered?, :check_version!, :open_next!, :close_round!, :hold_results!, :append_round!, :append_session!
  end
end
