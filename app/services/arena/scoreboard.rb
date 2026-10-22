module Arena
  class Scoreboard
    VERSION = Scoring::LEGACY

    def self.rows(session)
      rounds = session.arena_rounds.where(state: "results").order(:position).includes(:arena_question_snapshot).to_a
      answers = ArenaAnswer.where(arena_round_id: rounds.map(&:id)).index_by { |answer| [answer.arena_membership_id, answer.arena_round_id] }
      raise InvalidContent, "Unknown scoring version" unless Scoring::VERSIONS.include?(session.scoring_version)
      speed = session.scoring_version == Scoring::CURRENT
      duration_ms = session.duration_seconds.to_i * 1000
      rows = session.arena_memberships.order(:created_at, :id).filter_map do |member|
        next if speed && member.status == "removed" && answers.keys.none? { |key| key.first == member.id }
        streak, correct, total_points, response_time = 0, 0, 0, 0
        round_scores = {}
        eligible_total = 0
        rounds.each do |round|
          unless Playback.eligible?(session, round, member)
            round_scores[round.id] = { points: 0, speed_points: 0, streak_bonus: 0, streak: streak, technical_exclusion: true }
            next
          end
          eligible_total += 1
          answer = answers[[member.id, round.id]]
          right = answer && answer.option_id == round.arena_question_snapshot.payload.fetch("correct_option_id")
          streak = right ? streak + 1 : 0
          correct += 1 if right
          points = if right
            speed ? Scoring.points(duration_ms: duration_ms, elapsed_ms: answer.response_elapsed_ms, streak: streak) : 1000
          else
            0
          end
          bonus = speed && right ? 100 * [streak - 1, 4].min : 0
          response_time += speed && right ? answer.response_elapsed_ms : duration_ms
          total_points += points
          round_scores[round.id] = { points: points, speed_points: points - bonus, streak_bonus: bonus, streak: streak }
        end
        { membership_id: member.id, nickname: member.nickname, avatar_id: member.avatar_id,
          correct: correct, total: eligible_total, points: total_points, streak: streak,
          response_time_ms: response_time, round_scores: round_scores }
      end.sort_by { |row| [(session.listening_policy == "sequence-v1" && row[:total].zero? ? 1 : 0), -row[:points], (speed ? row[:response_time_ms] : 0), row[:nickname], row[:membership_id]] }
      previous, place = nil, 0
      rows.each_with_index do |row, index|
        if session.listening_policy == "sequence-v1" && row[:total].zero?
          row[:place] = nil
          next
        end
        tie = [row[:points], (speed ? row[:response_time_ms] : 0)]
        place = rows.take(index + 1).count { |item| !(session.listening_policy == "sequence-v1" && item[:total].zero?) } if tie != previous
        row[:place] = place
        previous = tie
      end
      rows
    end
  end
end
