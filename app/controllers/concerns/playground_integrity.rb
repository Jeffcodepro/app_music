module PlaygroundIntegrity
  extend ActiveSupport::Concern

  included do
    before_action :validate_playground_submission!, only: :submit_playground_answer
    rescue_from RhythmExerciseGenerator::GenerationError, with: :playground_generation_failed
    rescue_from ExerciseIntegrityValidator::Invalid, with: :playground_generation_failed
  end

  private

  def validate_playground_submission!
    @playground_submission = ExerciseSubmission.call(
      user: current_user, area: params[:activity].to_s,
      assignment_id: params[:assignment_id], attempt_token: params[:attempt_token],
      selected_option_id: params[:selected_option_id].to_s, playback_status: params[:playback_status]
    )
    if @playground_submission.duplicate
      redirect_to app_playground_path(activity: params[:activity], **playground_return_preferences), status: :see_other,
                  notice: "Esse envio já foi contabilizado."
    end
  rescue ExerciseSubmission::Rejected => error
    redirect_to app_playground_path(activity: params[:activity], **playground_return_preferences), status: :see_other, alert: error.message
  end

  # A neutral rejection or replay must keep the current exercise configuration.
  def playground_return_preferences
    case params[:activity]
    when "percepcao" then perception_preferences
    when "leitura" then reading_preferences
    when "ritmica" then rhythm_preferences
    when "harmonia" then harmony_preferences
    else {}
    end
  end

  def issue_playground_assignment(area, exercise)
    ExerciseAssignment.issue!(user: current_user, area:, exercise:)
  end

  def assigned_playground_exercise(area, exercise, assignment_id)
    return if exercise.blank? || assignment_id.blank?

    ExerciseIntegrityValidator.validate!(area, exercise)
    assignment = current_user.exercise_assignments.find_by(public_id: assignment_id, area:)
    return unless assignment && assignment.expires_at > Time.current && assignment.rules_version == ExerciseAssignment::RULES_VERSION

    stored = assignment.exercise_payload.deep_symbolize_keys
    ExerciseIntegrityValidator.validate!(area, stored)
    return unless assignment.content_digest == ExerciseIntegrityValidator.digest(area, stored)

    compact_method = { "leitura" => :compact_reading_exercise_storage, "harmonia" => :compact_harmony_exercise_storage,
                       "ritmica" => :compact_rhythm_exercise_storage }[area]
    matches = if compact_method
                send(compact_method, exercise) == send(compact_method, stored)
              else
                ExerciseIntegrityValidator.digest(area, exercise) == assignment.content_digest
              end
    return unless matches

    assignment.exercise
  rescue ExerciseIntegrityValidator::Invalid
    nil
  end

  def playground_generation_failed(error)
    Rails.logger.warn("playground_generation_failed type=#{error.class.name}")
    redirect_to app_pratica_path, alert: "Não foi possível gerar uma rodada válida. Tente novamente; nenhuma resposta foi contabilizada."
  end

  def validated_hydration(area)
    exercise = yield
    ExerciseIntegrityValidator.validate!(area, exercise) if exercise
    exercise
  rescue ExerciseIntegrityValidator::Invalid, KeyError, ArgumentError, TypeError, IndexError, NoMethodError
    nil
  end
end
