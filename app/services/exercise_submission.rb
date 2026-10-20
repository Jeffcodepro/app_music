class ExerciseSubmission
  class Rejected < StandardError; end
  Result = Struct.new(:exercise, :correct, :duplicate, :xp_earned, keyword_init: true)
  UUID = /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i

  def self.call(user:, area:, assignment_id:, attempt_token:, selected_option_id:, playback_status: nil)
    raise Rejected, "Atualize a rodada antes de responder." unless UUID.match?(assignment_id.to_s) && UUID.match?(attempt_token.to_s)

    assignment = ExerciseAssignment.find_by(public_id: assignment_id, user_id: user.id, area:)
    raise Rejected, "Esta rodada não pertence à sua sessão de estudo." unless assignment

    assignment.with_lock do
      raise Rejected, "Esta rodada expirou. Gere outro exercício." if assignment.expires_at <= Time.current
      raise Rejected, "A versão desta rodada precisa ser atualizada." unless assignment.rules_version == ExerciseAssignment::RULES_VERSION

      exercise = assignment.exercise_payload.deep_symbolize_keys
      ExerciseIntegrityValidator.validate!(area, exercise)
      unless assignment.content_digest == ExerciseIntegrityValidator.digest(area, exercise)
        raise Rejected, "Os dados desta rodada são inconsistentes. Gere outro exercício."
      end
      previous = assignment.exercise_attempts.find_by(attempt_token:)
      if previous
        raise Rejected, "Este envio já foi usado com outra alternativa." unless previous.selected_option_id == selected_option_id
        next Result.new(exercise: assignment.exercise, correct: previous.correct, duplicate: true, xp_earned: 0)
      end

      raise Rejected, "Esta tentativa não está mais disponível." if assignment.completed_at || assignment.answer_token != attempt_token
      raise Rejected, "Selecione uma alternativa desta rodada." unless exercise.fetch(:options).any? { |option| option[:id] == selected_option_id }
      if area != "leitura" && playback_status != "ready"
        raise Rejected, "O áudio não foi concluído. Reproduza novamente; nenhuma resposta foi contabilizada."
      end

      correct = selected_option_id == exercise.fetch(:correct_option_id)
      activity = assignment.study_activity
      total_credit = correct ? 20 : (activity&.xp_earned || 6)
      delta = total_credit - (activity&.xp_earned || 0)
      assignment.exercise_attempts.create!(attempt_token:, selected_option_id:, correct:, xp_earned: delta)
      if activity
        activity.update!(xp_earned: total_credit) if delta.positive?
      else
        StudyActivity.create!(user:, exercise_assignment: assignment, area:, xp_earned: total_credit,
                              minutes_practiced: 3, occurred_on: Date.current)
      end
      assignment.update!(answer_token: SecureRandom.uuid, completed_at: correct ? Time.current : nil)
      Result.new(exercise: assignment.exercise, correct:, duplicate: false, xp_earned: delta)
    end
  rescue ExerciseIntegrityValidator::Invalid => error
    raise Rejected, "Exercício inconsistente (#{error.message}). Gere outra rodada; nenhuma resposta foi contabilizada."
  end
end
