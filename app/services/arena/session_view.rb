module Arena
  class SessionView
    def self.call(actor:, session:)
      SchemaIntegrity.verify!
      options = ArenaSession.connection.transaction_open? ? {} : { isolation: :repeatable_read }
      ArenaSession.uncached do
        ArenaSession.transaction(**options) do
          session = ArenaSession.find(session.id)
          policy = SessionPolicy.new(actor, session)
          host = policy.control?
          return AudioCheck.exclusion_view(session, actor: actor) if !host && AudioCheck.excluded?(session,actor)
          raise Forbidden unless policy.view?
          now = DatabaseClock.now
          member = session.arena_memberships.find_by(user: actor, status: %w[active left])
          departed = member&.status == "left"
          round = session.arena_rounds.where.not(state: "queued").order(position: :desc).includes(:arena_question_snapshot).first
          phase = phase_for(session, round)
          transition = if AudioCheck.pending?(session)
            session.audio_check_deadline_at
          elsif session.state == "live" && round
            { "ready" => round.answer_open_at || (Playback.ends_at(session, round) if Playback.sequenced?(session, round)), "answering" => round.deadline_at, "results" => round.advance_at }[round.state]
          end
          result = { id: session.id, title: session.title, state: session.state, experience: session.experience,
            visibility: session.visibility, presentation_mode: session.presentation_mode, capacity: session.capacity, scoring_version: session.scoring_version, listening_policy: session.listening_policy, listening_repetitions: session.listening_repetitions,
            audio_required: (session.presentation_mode == "presenter" ? host : member&.status == "active") && AudioCheck.audio?(session),
            audio_check: AudioCheck.summary(session, actor: actor), audio_check_attempted: session.audio_check_id.present?, host_audio_excluded: host && AudioCheck.excluded?(session,actor),
            version: session.lock_version, sequence: session.event_sequence, host: host, participant: member&.status == "active", departed: departed,
            participant_count: session.arena_memberships.where(status: "active").count,
            question_count: session.arena_rounds.count, server_now: now.iso8601(3), phase: phase,
            next_transition_at: transition&.iso8601(3),
            phase_started_at: (phase == "podium" ? session.ended_at : (round&.answer_open_at if phase == "countdown"))&.iso8601(3),
            technical_preview: session.arena_question_snapshots.order(:created_at).first&.payload&.fetch("source_status", nil) == "technical_preview" }
          result[:identity_required] = host && session.party? && member.nil? && session.state == "lobby_open"
          if host && session.host_ready?
            result[:invite] = { code: Invites.code(session), expires_at: session.invite_expires_at&.iso8601(3), expired: session.invite_expires_at.nil? || now >= session.invite_expires_at } if session.invite_ciphertext
          end
          scores = Scoreboard.rows(session)
          own = member && scores.find { |row| row[:membership_id] == member.id }
          if !departed && %w[lobby_open lobby_locked].include?(session.state) && !AudioCheck.pending?(session)
            result[:roster] = session.arena_memberships.where(status: "active").order(:created_at).map do |membership|
              row = { key: Digest::SHA256.hexdigest("#{session.id}:#{membership.id}").first(20), nickname: membership.nickname,
                avatar_id: membership.avatar_id, active: true, you: membership.id == member&.id,
                removable: host && membership.user_id != actor.id && !AudioCheck.pending?(session),
                audio_ready: membership.audio_ready_at.present? }
              row[:id] = membership.id if host
              row
            end
          end
          result[:own_identity] = { nickname: member.nickname, avatar_id: member.avatar_id } if member
          result[:round] = project_round(session, round, member, now, own, actor) if round && !departed
          result[:own_result] = own.slice(:points, :correct, :total, :place, :streak) if own
          can_see_scores = host || ((session.party? || session.presentation_mode == "presenter") && member)
          if can_see_scores && ((!departed && round&.state == "results") || ArenaSession::TERMINAL.include?(session.state))
            result[:ranking] = scores.map { |row| row.except(:membership_id, :round_scores, :response_time_ms).merge(you: row[:membership_id] == member&.id) }
          end
          if can_see_scores && session.state == "completed"
            result[:podium] = result.fetch(:ranking, []).select { |row| row[:place] && row[:place] <= 3 }
          end
          result[:share] = ScoreShare.call(actor: actor, session: session) if member && own && ArenaSession::TERMINAL.include?(session.state)
          result[:phase] = "departed" if departed && !ArenaSession::TERMINAL.include?(session.state)
          result[:next_transition_at] = nil if departed
          if session.rematch_session_id
            next_room = session.rematch_session
            if session.party? && member&.status == "active" && next_room.state == "lobby_open" && now < next_room.invite_expires_at
              result[:rematch_code] = Invites.code(next_room)
            end
          end
          result
        end
      end
    end

    def self.project_round(session, round, member, now, own, actor)
      snapshot = round.arena_question_snapshot
      answer = member && ArenaAnswer.find_by(arena_membership_id: member.id, arena_round_id: round.id)
      listening = Playback.audio?(round) && %w[ready answering paused].include?(round.state)
      show_question = listening || %w[answering results void].include?(round.state) || (round.state == "paused" && round.paused_from == "answering")
      eligible = session.arena_memberships.where(status: "active")
      result = { id: round.id, position: round.position, state: round.state, paused_from: round.paused_from,
        deadline_at: round.deadline_at&.iso8601(3), answer_open_at: round.answer_open_at&.iso8601(3), advance_at: round.advance_at&.iso8601(3),
        remaining_ms: round.remaining_ms, question: (Projections.question(snapshot) if show_question),
        answered: answer.present?, selected_option_id: answer&.option_id,
        answered_count: ArenaAnswer.where(arena_round: round, arena_membership_id: eligible.select(:id)).count,
        technical_exclusion: member.present? && Playback.sequenced?(session, round) && !Playback.eligible?(session, round, member),
        can_answer: member.present? && Playback.eligible?(session, round, member) && answer.nil? && session.state == "live" && round.state == "answering" && now >= round.answer_open_at && now < round.deadline_at }
      result[:playback] = Playback.summary(session, round, actor: actor) if listening
      if round.state == "results"
        correct_id = snapshot.payload.fetch("correct_option_id")
        correct_choice = snapshot.payload.fetch("options").find { |option| option["id"] == correct_id }
        result[:result] = { correct_option_id: correct_id,
          correct_label: correct_choice.fetch("label"), correct_svg: correct_choice["svg"],
          correct: answer && answer.option_id == correct_id, **(own&.dig(:round_scores, round.id) || { points: 0, speed_points: 0, streak_bonus: 0, streak: 0 }) }
      end
      result
    end

    def self.phase_for(session, round)
      return "podium" if session.state == "completed"
      return "ended" if ArenaSession::TERMINAL.include?(session.state)
      return "paused" if session.state == "paused"
      return "audio_check" if AudioCheck.pending?(session)
      return "lobby" unless round
      return "listening" if round.state == "ready" && Playback.audio?(round) && round.answer_open_at.nil?
      { "ready" => "countdown", "answering" => "question", "results" => "feedback", "paused" => "paused", "void" => "void" }.fetch(round.state, "preparing")
    end
    private_class_method :project_round, :phase_for
  end
end
