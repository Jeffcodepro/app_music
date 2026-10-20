class StudentHubController < ApplicationController
  DEFAULT_PLAYGROUND_ACTIVITY = "percepcao".freeze
  READING_PLAYGROUND_STATE_FALLBACK_STORE = ActiveSupport::Cache::MemoryStore.new(expires_in: 12.hours)
  HARMONY_PLAYGROUND_STATE_FALLBACK_STORE = ActiveSupport::Cache::MemoryStore.new(expires_in: 12.hours)
  RHYTHM_PLAYGROUND_STATE_FALLBACK_STORE = ActiveSupport::Cache::MemoryStore.new(expires_in: 12.hours)
  before_action :authenticate_user!
  layout "platform"
  include PlaygroundIntegrity

  def trail_show
    @area = params[:area].to_s.presence || "ritmica"
    @level = params[:nivel].to_s.presence || "1"
  end

  # Legacy lesson URLs stay valid while the real catalog is prepared.
  def lesson_show; end

  def practice_result; end

  def playground
    @playground_activities = helpers.playground_activity_catalog
    @selected_activity = helpers.playground_activity_for(params[:activity]) || helpers.playground_activity_for(DEFAULT_PLAYGROUND_ACTIVITY)
    @playground_feedback = flash[:playground_feedback]&.to_h&.deep_symbolize_keys
    @playground_feedback = nil if @playground_feedback.present? && @playground_feedback[:activity] != @selected_activity[:slug]
    @perception_autoplay = params[:refresh] == "1" && params[:autoplay] == "1"

    case @selected_activity[:slug]
    when "percepcao"
      prepare_perception_playground!
      clear_perception_feedback_if_starting_new_round!
      store_new_perception_exercise! if should_refresh_perception_exercise?
      @perception_exercise = current_perception_exercise
    when "leitura"
      prepare_reading_playground!
      clear_reading_feedback_if_starting_new_round!
      store_new_reading_exercise! if should_refresh_reading_exercise?
      @reading_exercise = current_reading_exercise
    when "ritmica"
      prepare_rhythm_playground!
      clear_rhythm_feedback_if_starting_new_round!
      store_new_rhythm_exercise! if should_refresh_rhythm_exercise?
      @rhythm_exercise = current_rhythm_exercise
    when "harmonia"
      prepare_harmony_playground!
      clear_harmony_feedback_if_starting_new_round!
      store_new_harmony_exercise! if should_refresh_harmony_exercise?
      @harmony_exercise = current_harmony_exercise
    end
  end

  def submit_playground_answer
    selected_activity = helpers.playground_activity_for(params[:activity])

    case selected_activity&.dig(:slug)
    when "percepcao"
      submit_perception_playground_answer
    when "leitura"
      submit_reading_playground_answer
    when "ritmica"
      submit_rhythm_playground_answer
    when "harmonia"
      submit_harmony_playground_answer
    else
      redirect_to app_playground_path(activity: params[:activity].presence || DEFAULT_PLAYGROUND_ACTIVITY),
                  alert: "Esse playground ainda está em construção."
    end
  end

  def submit_perception_playground_answer
    exercise = @playground_submission.exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "percepcao", refresh: 1, **perception_preferences),
                  alert: "Gere um novo intervalo antes de responder."
      return
    end

    preferences = perception_preferences
    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = @playground_submission.correct

    record_perception_playground_attempt!(correct:)
    @playground_feedback = build_perception_playground_feedback(exercise:, selected_option:, correct:)
    prepare_perception_playground!
    @perception_exercise = exercise

    if turbo_frame_request?
      render_perception_playground_frame
    else
      flash[:playground_feedback] = @playground_feedback
      redirect_to app_playground_path(activity: "percepcao", **preferences)
    end
  end

  def challenges; end

  def ranking; end

  def achievements; end

  def scholarship; end

  def plans_compare; end

  def billing_history; end

  private

  def current_perception_exercise
    if session[:perception_assignment_id].present?
      assignment = current_user.exercise_assignments.find_by(public_id: session[:perception_assignment_id], area: "percepcao")
      return assigned_playground_exercise("percepcao", assignment&.exercise, assignment&.public_id)
    end
    exercise = session[:perception_interval_exercise]&.to_h&.deep_symbolize_keys
    assigned_playground_exercise("percepcao", exercise, exercise&.dig(:assignment_id))
  end

  def current_reading_exercise
    stored_exercise = reading_playground_state[:exercise]&.to_h
    assigned_playground_exercise("leitura", hydrate_stored_reading_exercise_payload(stored_exercise), reading_playground_state[:assignment_id])
  end

  def previous_reading_exercise
    stored_exercise = reading_playground_state[:previous_exercise]&.to_h
    hydrate_stored_reading_exercise_payload(stored_exercise)
  end

  def previous_reading_exercise_answered?
    reading_playground_state[:previous_exercise_answered] == true
  end

  def hydrate_stored_reading_exercise_payload(stored_exercise)
    return if stored_exercise.blank?

    compact_exercise = normalize_reading_exercise_storage(stored_exercise)
    return if compact_exercise.blank?

    hydrate_reading_exercise(compact_exercise)
  end

  def current_harmony_exercise
    stored_exercise = harmony_playground_state[:exercise]&.to_h&.stringify_keys
    return if stored_exercise.blank?

    compact_exercise = normalize_harmony_exercise_storage(stored_exercise)
    return if compact_exercise.blank?

    write_harmony_playground_state(exercise: compact_exercise) if stored_exercise != compact_exercise
    assigned_playground_exercise("harmonia", hydrate_harmony_exercise(compact_exercise), harmony_playground_state[:assignment_id])
  end

  def current_rhythm_exercise
    stored_exercise = rhythm_playground_state[:exercise]&.to_h&.stringify_keys
    return if stored_exercise.blank?

    compact_exercise = normalize_rhythm_exercise_storage(stored_exercise)
    return if compact_exercise.blank?

    write_rhythm_playground_state(exercise: compact_exercise) if stored_exercise != compact_exercise
    assigned_playground_exercise("ritmica", hydrate_rhythm_exercise(compact_exercise), rhythm_playground_state[:assignment_id])
  end

  def prepare_perception_playground!
    @perception_instruments = PerceptionIntervalExerciseGenerator.instruments
    @perception_direction_modes = PerceptionIntervalExerciseGenerator.direction_modes
    @perception_preferences = perception_preferences
    if @perception_preferences[:question_mode] == "melodic_dictation" && @perception_preferences[:level] == 4 && @perception_preferences[:instrument] == "piano"
      @perception_instruments = @perception_instruments.select { |instrument| instrument[:id] == "piano" }
    end
    @perception_scoreboard = perception_scoreboard
  end

  def prepare_reading_playground!
    @reading_clef_modes = ReadingNoteExerciseGenerator.clef_modes
    @reading_question_modes = ReadingNoteExerciseGenerator.question_modes
    @reading_season_modes = ReadingNoteExerciseGenerator.season_modes
    @reading_preferences = reading_preferences
    @reading_scoreboard = reading_scoreboard
  end

  def prepare_harmony_playground!
    @harmony_preferences = harmony_preferences
    level = @harmony_preferences[:level]
    @harmony_question_modes = HarmonyExerciseGenerator.question_modes.select { |m| !level || m[:id] == "mixed" || ListeningDifficulty.harmony_modes(level).include?(m[:id]) }
    @harmony_chord_structures = HarmonyExerciseGenerator.chord_structures.select { |s| !level || ListeningDifficulty.harmony_structures(level).include?(s[:id]) }
    @harmony_instruments = PerceptionIntervalExerciseGenerator.instruments
    @harmony_scoreboard = harmony_scoreboard
  end

  def prepare_rhythm_playground!
    @rhythm_activity_modes = RhythmExerciseGenerator.activity_modes
    @rhythm_preferences = rhythm_preferences
    @rhythm_scoreboard = rhythm_scoreboard
  end

  def should_refresh_perception_exercise?
    return true if params[:refresh].present?
    return true if current_perception_exercise.blank?

    exercise = current_perception_exercise
    return true if exercise[:level] != @perception_preferences[:level]
    return true if (exercise[:question_mode] || "interval") != @perception_preferences[:question_mode]
    return true if exercise[:instrument] != @perception_preferences[:instrument]
    return false if @perception_preferences[:question_mode] == "melodic_dictation"

    exercise[:direction_mode] != @perception_preferences[:direction_mode]
  end

  def should_refresh_reading_exercise?
    return true if params[:refresh].present?
    return true if current_reading_exercise.blank?

    current_reading_exercise[:clef_mode] != @reading_preferences[:clef_mode] ||
      current_reading_exercise[:question_mode] != @reading_preferences[:question_mode] ||
      current_reading_exercise[:season_mode] != @reading_preferences[:season_mode]
  end

  def should_refresh_harmony_exercise?
    return true if params[:refresh].present?
    return true if current_harmony_exercise.blank?

    current_harmony_exercise[:level] != @harmony_preferences[:level] ||
      (current_harmony_exercise[:instrument].presence || "piano") != @harmony_preferences[:instrument] ||
      current_harmony_exercise[:question_mode] != @harmony_preferences[:question_mode] ||
      current_harmony_exercise[:chord_structure] != @harmony_preferences[:chord_structure]
  end

  def should_refresh_rhythm_exercise?
    return true if params[:refresh].present?
    return true if current_rhythm_exercise.blank?
    if @rhythm_preferences[:level].present?
      return current_rhythm_exercise[:level] != @rhythm_preferences[:level] ||
        (current_rhythm_exercise[:requested_meter_id] || current_rhythm_exercise[:meter_id]) != @rhythm_preferences[:meter_id] ||
        current_rhythm_exercise[:requested_activity_mode] != @rhythm_preferences[:activity_mode]
    end
    return false if @rhythm_preferences[:activity_mode] == RhythmExerciseGenerator::DEFAULT_ACTIVITY_MODE

    current_rhythm_exercise[:activity_mode] != @rhythm_preferences[:activity_mode]
  end

  def store_new_perception_exercise!(preferences = perception_preferences)
    recent = perception_recent_exercises.select { |entry| (entry[:question_mode] || "interval") == preferences[:question_mode] }
    exercise = if preferences[:question_mode] == "melodic_dictation"
                 if preferences[:level]
                   VoicedDictationExerciseGenerator.new(level: preferences[:level], instrument: preferences[:instrument], recent_exercises: recent).call
                 else
                   MelodicDictationExerciseGenerator.new(instrument: preferences[:instrument], recent_exercises: recent).call
                 end
               else
                 PerceptionIntervalExerciseGenerator.new(
                   direction_mode: preferences[:direction_mode], instrument: preferences[:instrument], recent_exercises: recent, level: preferences[:level]
                 ).call
               end

    assignment = issue_playground_assignment("percepcao", exercise)
    session[:perception_assignment_id] = assignment.public_id
    session.delete(:perception_interval_exercise)
    store_recent_perception_exercise!(exercise)
  end

  def store_new_reading_exercise!(preferences = reading_preferences)
    previous_exercise = reading_playground_state[:exercise]&.to_h
    updates = {}
    if previous_exercise.present?
      updates[:previous_exercise] = previous_exercise
      updates[:previous_exercise_answered] = @playground_feedback.present? && @playground_feedback[:correct]
    else
      updates[:previous_exercise] = nil
      updates[:previous_exercise_answered] = nil
    end

    exercise = ReadingNoteExerciseGenerator.new(
      clef_mode: preferences[:clef_mode],
      question_mode: preferences[:question_mode],
      season_mode: preferences[:season_mode],
      recent_exercises: reading_recent_exercises
    ).call

    assignment = issue_playground_assignment("leitura", exercise)

    write_reading_playground_state(
      updates.merge(
        assignment_id: assignment.public_id,
        exercise: compact_reading_exercise_storage(exercise),
        recent_exercises: next_reading_recent_exercises(exercise)
      )
    )
  end

  def store_new_harmony_exercise!(preferences = harmony_preferences)
    exercise = HarmonyExerciseGenerator.new(
      instrument: preferences[:instrument],
      level: preferences[:level],
      question_mode: preferences[:question_mode],
      chord_structure: preferences[:chord_structure],
      recent_exercises: harmony_recent_exercises
    ).call
    exercise[:instrument] = preferences[:instrument]

    assignment = issue_playground_assignment("harmonia", exercise)

    write_harmony_playground_state(
      assignment_id: assignment.public_id,
      exercise: compact_harmony_exercise_storage(exercise),
      recent_exercises: next_harmony_recent_exercises(exercise)
    )
  end

  def store_new_rhythm_exercise!(preferences = rhythm_preferences)
    exercise = if preferences[:level].present?
                 MetricalRhythmExerciseGenerator.new(level: preferences[:level], meter_id: preferences[:meter_id],
                   activity_mode: preferences[:activity_mode], recent_exercises: rhythm_recent_exercises).call
               else
                 RhythmExerciseGenerator.new(activity_mode: preferences[:activity_mode], recent_exercises: rhythm_recent_exercises).call
               end

    assignment = issue_playground_assignment("ritmica", exercise)

    write_rhythm_playground_state(
      assignment_id: assignment.public_id,
      exercise: compact_rhythm_exercise_storage(exercise),
      recent_exercises: next_rhythm_recent_exercises(exercise)
    )
  end

  def build_perception_playground_feedback(exercise:, selected_option:, correct:)
    {
      activity: "percepcao",
      correct:,
      selected_label: selected_option&.dig(:label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      direction_label: exercise[:direction_label],
      assignment_id: exercise[:assignment_id],
      question_mode: exercise[:question_mode] || "interval",
      notes: exercise[:question_type] == "melodic_dictation" ? nil : localized_pitch_pair(exercise[:reference_pitch], exercise[:target_pitch]),
      answered: true
    }
  end

  def build_reading_playground_feedback(exercise:, selected_option:, correct:)
    {
      activity: "leitura",
      assignment_id: exercise[:assignment_id],
      correct:,
      selected_label: selected_option&.dig(:label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      question_type_label: exercise[:question_type_label],
      season_label: exercise[:season_label],
      clef_label: exercise[:clef_label],
      note_label: exercise[:pitch_label],
      exercise_signature: exercise[:signature],
      synchronization_error: false,
      answered: true
    }
  end

  def build_harmony_playground_feedback(exercise:, selected_option:, correct:)
    {
      activity: "harmonia",
      assignment_id: exercise[:assignment_id],
      correct:,
      selected_label: selected_option&.dig(:label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      question_type_label: exercise[:question_type_label],
      key_label: exercise[:key_label],
      chord_label: exercise[:chord_notes_label],
      exercise_signature: exercise[:signature],
      synchronization_error: false,
      answered: true
    }
  end

  def build_rhythm_playground_feedback(exercise:, selected_option:, correct:)
    {
      activity: "ritmica",
      assignment_id: exercise[:assignment_id],
      correct:,
      selected_label: selected_option&.dig(:aria_label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      activity_mode_label: exercise[:activity_mode_label],
      tempo_label: "#{exercise[:tempo_bpm]} BPM",
      exercise_signature: exercise[:signature],
      synchronization_error: false,
      answered: true
    }
  end

  def render_perception_playground_frame
    render partial: "student_hub/perception_playground",
           locals: {
             perception_exercise: @perception_exercise,
             perception_preferences: @perception_preferences,
             perception_instruments: @perception_instruments,
             perception_direction_modes: @perception_direction_modes,
             playground_feedback: @playground_feedback,
             perception_scoreboard: perception_scoreboard,
             perception_autoplay: @perception_autoplay
           }
  end

  def render_reading_playground_frame
    render partial: "student_hub/reading_playground",
           locals: {
             reading_exercise: @reading_exercise,
             reading_preferences: @reading_preferences,
             reading_clef_modes: @reading_clef_modes,
             reading_question_modes: @reading_question_modes,
             reading_season_modes: @reading_season_modes,
             playground_feedback: @playground_feedback,
             reading_scoreboard: reading_scoreboard
           }
  end

  def render_harmony_playground_frame
    render partial: "student_hub/harmony_playground",
           locals: {
             harmony_exercise: @harmony_exercise,
             harmony_preferences: @harmony_preferences,
             harmony_question_modes: @harmony_question_modes,
             harmony_chord_structures: @harmony_chord_structures,
             harmony_instruments: @harmony_instruments,
             playground_feedback: @playground_feedback,
             harmony_scoreboard: harmony_scoreboard
           }
  end

  def render_rhythm_playground_frame
    render partial: "student_hub/rhythm_playground",
           locals: {
             rhythm_exercise: @rhythm_exercise,
             rhythm_preferences: @rhythm_preferences,
             rhythm_activity_modes: @rhythm_activity_modes,
             playground_feedback: @playground_feedback,
             rhythm_scoreboard: rhythm_scoreboard
           }
  end

  def record_perception_playground_attempt!(correct:)
    scoreboard = perception_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    session[:perception_scoreboard] = scoreboard.stringify_keys
  end

  def record_reading_playground_attempt!(correct:)
    scoreboard = reading_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    write_reading_playground_state(scoreboard: scoreboard.stringify_keys)
  end

  def record_harmony_playground_attempt!(correct:)
    scoreboard = harmony_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    write_harmony_playground_state(scoreboard: scoreboard.stringify_keys)
  end

  def record_rhythm_playground_attempt!(correct:)
    scoreboard = rhythm_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    write_rhythm_playground_state(scoreboard: scoreboard.stringify_keys)
  end

  def perception_preferences
    exercise = @playground_submission&.exercise || current_perception_exercise
    preferences = {
      question_mode: %w[interval melodic_dictation].include?(params[:question_mode]) ? params[:question_mode] : (exercise&.dig(:question_mode) || "interval"),
      instrument: sanitize_perception_instrument(params.key?(:instrument) ? params[:instrument] : exercise&.dig(:instrument)),
      direction_mode: sanitize_perception_direction_mode(params.key?(:direction_mode) ? params[:direction_mode] : exercise&.dig(:direction_mode)),
      level: listening_level_for(exercise)
    }
    legacy_pending = exercise&.dig(:dictation_format) == "voices-v1" && ( @playground_submission || !(params.key?(:level) || params.key?(:instrument) || params[:refresh].present?) )
    if preferences[:question_mode] == "melodic_dictation" && preferences[:level] == 4 && !legacy_pending
      preferences[:instrument] = "piano"
    end
    preferences
  end

  def reading_preferences
    {
      clef_mode: sanitize_reading_clef_mode(params[:clef_mode]),
      question_mode: sanitize_reading_question_mode(params[:question_mode]),
      season_mode: sanitize_reading_season_mode(params[:season_mode])
    }
  end

  def harmony_preferences
    exercise = @playground_submission&.exercise || current_harmony_exercise
    level = listening_level_for(exercise)
    mode = sanitize_harmony_question_mode(params.key?(:question_mode) ? params[:question_mode] : exercise&.dig(:question_mode))
    structure = sanitize_harmony_chord_structure(params.key?(:chord_structure) ? params[:chord_structure] : exercise&.dig(:chord_structure))
    if level
      unless mode == "mixed" || ListeningDifficulty.harmony_modes(level).include?(mode)
        mode = "mixed"
        @harmony_level_adjusted = true
      end
      unless ListeningDifficulty.harmony_structures(level).include?(structure)
        structure = "triad"
        @harmony_level_adjusted = true
      end
    end
    { level:, question_mode: mode, chord_structure: structure,
      instrument: sanitize_harmony_instrument(params.key?(:instrument) ? params[:instrument] : exercise&.dig(:instrument)) }
  end

  def listening_level_for(exercise)
    return exercise&.dig(:level) if @playground_submission
    return exercise&.dig(:level) unless params.key?(:level)
    return if params[:level].blank?
    %w[1 2 3 4].include?(params[:level].to_s) ? params[:level].to_i : 1
  end

  def rhythm_preferences
    preferences = { activity_mode: sanitize_rhythm_activity_mode(params[:activity_mode]) }
    if params[:level].blank? && params[:meter_id].blank?
      exercise = current_rhythm_exercise
      return preferences unless exercise&.dig(:rhythm_format) == "meter-v1"
      preferences[:activity_mode] = exercise[:requested_activity_mode] if params[:activity_mode].blank?
      return preferences.merge(level: exercise[:level], meter_id: exercise[:requested_meter_id] || exercise[:meter_id])
    end

    level = %w[1 2 3 4].include?(params[:level].to_s) ? params[:level].to_i : 1
    available = ["mixed"] + MusicTheory::Meter.presets(level:).map { |preset| preset[:id] }
    preferences.merge(level:, meter_id: available.include?(params[:meter_id]) ? params[:meter_id] : "4-4")
  end

  def sanitize_perception_instrument(instrument)
    instrument = instrument.to_s
    return instrument if PerceptionIntervalExerciseGenerator.instrument_ids.include?(instrument)

    PerceptionIntervalExerciseGenerator::DEFAULT_INSTRUMENT
  end

  def sanitize_perception_direction_mode(direction_mode)
    direction_mode = direction_mode.to_s
    return direction_mode if PerceptionIntervalExerciseGenerator.direction_mode_ids.include?(direction_mode)

    PerceptionIntervalExerciseGenerator::DEFAULT_DIRECTION_MODE
  end

  def sanitize_reading_clef_mode(clef_mode)
    clef_mode = clef_mode.to_s
    return clef_mode if ReadingNoteExerciseGenerator.clef_mode_ids.include?(clef_mode)

    ReadingNoteExerciseGenerator::DEFAULT_CLEF_MODE
  end

  def sanitize_reading_question_mode(question_mode)
    question_mode = question_mode.to_s
    return question_mode if ReadingNoteExerciseGenerator.question_mode_ids.include?(question_mode)

    ReadingNoteExerciseGenerator::DEFAULT_QUESTION_MODE
  end

  def sanitize_reading_season_mode(season_mode)
    season_mode = season_mode.to_s
    return season_mode if ReadingNoteExerciseGenerator.season_mode_ids.include?(season_mode)

    ReadingNoteExerciseGenerator::DEFAULT_SEASON_MODE
  end

  def sanitize_harmony_question_mode(question_mode)
    question_mode = question_mode.to_s
    return question_mode if HarmonyExerciseGenerator.question_mode_ids.include?(question_mode)

    HarmonyExerciseGenerator::DEFAULT_QUESTION_MODE
  end

  def sanitize_harmony_chord_structure(chord_structure)
    chord_structure = chord_structure.to_s
    return chord_structure if HarmonyExerciseGenerator.chord_structure_ids.include?(chord_structure)

    HarmonyExerciseGenerator::DEFAULT_CHORD_STRUCTURE
  end

  def sanitize_harmony_instrument(instrument)
    instrument = instrument.to_s
    return instrument if PerceptionIntervalExerciseGenerator.instrument_ids.include?(instrument)

    PerceptionIntervalExerciseGenerator::DEFAULT_INSTRUMENT
  end

  def sanitize_rhythm_activity_mode(activity_mode)
    activity_mode = activity_mode.to_s
    raise RhythmExerciseGenerator::GenerationError, "Syncopation is temporarily unavailable" if activity_mode == "syncopation"
    return activity_mode if RhythmExerciseGenerator.activity_mode_ids.include?(activity_mode)

    RhythmExerciseGenerator::DEFAULT_ACTIVITY_MODE
  end

  def localized_pitch_pair(reference_pitch, target_pitch)
    [
      PerceptionIntervalExerciseGenerator.localize_pitch_name(reference_pitch),
      PerceptionIntervalExerciseGenerator.localize_pitch_name(target_pitch)
    ].join(" → ")
  end

  def perception_scoreboard
    stored = session[:perception_scoreboard]&.to_h || {}
    {
      correct_count: stored["correct_count"].to_i,
      incorrect_count: stored["incorrect_count"].to_i
    }
  end

  def reading_scoreboard
    stored = reading_playground_state[:scoreboard].to_h
    {
      correct_count: (stored[:correct_count] || stored["correct_count"]).to_i,
      incorrect_count: (stored[:incorrect_count] || stored["incorrect_count"]).to_i
    }
  end

  def harmony_scoreboard
    stored = harmony_playground_state[:scoreboard].to_h
    {
      correct_count: (stored[:correct_count] || stored["correct_count"]).to_i,
      incorrect_count: (stored[:incorrect_count] || stored["incorrect_count"]).to_i
    }
  end

  def rhythm_scoreboard
    stored = rhythm_playground_state[:scoreboard].to_h
    {
      correct_count: (stored[:correct_count] || stored["correct_count"]).to_i,
      incorrect_count: (stored[:incorrect_count] || stored["incorrect_count"]).to_i
    }
  end

  def perception_recent_exercises
    Array(session[:perception_recent_exercises]).map { |entry| entry.to_h.symbolize_keys }
  end

  def reading_recent_exercises
    Array(reading_playground_state[:recent_exercises]).filter_map do |entry|
      payload = entry.to_h.stringify_keys
      clef_id = payload["c"] || payload["clef_id"]
      staff_position_index = payload["p"] || payload["staff_position_index"]
      question_type = payload["t"] || payload["question_type"]
      season_id = payload["v"] || payload["season_id"]
      note_accidental_id = payload["n"] || payload["note_accidental_id"]
      key_signature_id = payload["k"] || payload["key_signature_id"]

      next if clef_id.blank? || question_type.blank?

      {
        clef_id:,
        question_type:,
        season_id:,
        staff_position_index: staff_position_index.presence&.to_i,
        note_accidental_id:,
        key_signature_id:
      }
    end
  end

  def harmony_recent_exercises
    Array(harmony_playground_state[:recent_exercises]).filter_map do |entry|
      payload = entry.to_h.symbolize_keys
      next if payload[:question_type].blank? || payload[:key_id].blank? || payload[:chord_structure].blank?

      {
        question_type: payload[:question_type],
        key_id: payload[:key_id],
        chord_structure: payload[:chord_structure],
        degree: payload[:degree].presence&.to_i,
        progression_template_id: payload[:progression_template_id],
        progression_focus_index: payload[:progression_focus_index].presence&.to_i
      }
    end
  end

  def rhythm_recent_exercises
    Array(rhythm_playground_state[:recent_exercises]).filter_map do |entry|
      payload = entry.to_h.symbolize_keys
      next if payload[:activity_mode].blank? || payload[:signature].blank?

      {
        activity_mode: payload[:activity_mode],
        meter_id: payload[:meter_id],
        signature: payload[:signature]
      }
    end
  end

  def store_recent_perception_exercise!(exercise)
    recent = perception_recent_exercises
    recent << {
      question_mode: exercise[:question_mode] || "interval",
      interval_id: exercise[:question_type] == "melodic_dictation" ? nil : exercise[:correct_option_id],
      signature: exercise[:signature]
    }
    session[:perception_recent_exercises] = recent.last(4).map(&:stringify_keys)
  end

  def store_recent_reading_exercise!(exercise)
    write_reading_playground_state(recent_exercises: next_reading_recent_exercises(exercise))
  end

  def store_recent_harmony_exercise!(exercise)
    write_harmony_playground_state(recent_exercises: next_harmony_recent_exercises(exercise))
  end

  def clear_perception_feedback_if_starting_new_round!
    @playground_feedback = nil if params[:refresh].present?
  end

  def clear_reading_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    @playground_feedback = nil if params[:refresh].present? || params[:clef_mode].present? || params[:question_mode].present? || params[:season_mode].present?
  end

  def clear_harmony_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    @playground_feedback = nil if params[:refresh].present? || params[:question_mode].present? || params[:chord_structure].present? || params[:instrument].present?
  end

  def clear_rhythm_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    @playground_feedback = nil if params[:refresh].present? || params[:activity_mode].present?
  end

  def submit_reading_playground_answer
    exercise = @playground_submission.exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "leitura", refresh: 1, **reading_preferences),
                  alert: "Gere uma nova nota antes de responder."
      return
    end

    preferences = reading_preferences
    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = @playground_submission.correct

    record_reading_playground_attempt!(correct:)
    @playground_feedback = build_reading_playground_feedback(exercise:, selected_option:, correct:)
    prepare_reading_playground!

    if correct
      store_new_reading_exercise!(preferences)
      @reading_exercise = current_reading_exercise
    else
      write_reading_playground_state(exercise: compact_reading_exercise_storage(exercise), assignment_id: exercise[:assignment_id])
      @reading_exercise = exercise
    end

    if turbo_frame_request?
      render_reading_playground_frame
    else
      flash[:playground_feedback] = @playground_feedback
      redirect_to app_playground_path(activity: "leitura", **preferences)
    end
  end

  def submit_harmony_playground_answer
    exercise = @playground_submission.exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "harmonia", refresh: 1, **harmony_preferences),
                  alert: "Gere um novo exercício de harmonia antes de responder."
      return
    end

    preferences = harmony_preferences
    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = @playground_submission.correct

    record_harmony_playground_attempt!(correct:)
    @playground_feedback = build_harmony_playground_feedback(exercise:, selected_option:, correct:)
    prepare_harmony_playground!

    if correct
      store_new_harmony_exercise!(preferences)
      @harmony_exercise = current_harmony_exercise
    else
      @harmony_exercise = exercise
    end

    if turbo_frame_request?
      render_harmony_playground_frame
    else
      flash[:playground_feedback] = @playground_feedback
      redirect_to app_playground_path(activity: "harmonia", **preferences)
    end
  end

  def submit_rhythm_playground_answer
    exercise = @playground_submission.exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "ritmica", refresh: 1, **rhythm_preferences),
                  alert: "Gere um novo exercício de rítmica antes de responder."
      return
    end

    preferences = rhythm_preferences
    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = @playground_submission.correct

    record_rhythm_playground_attempt!(correct:)
    @playground_feedback = build_rhythm_playground_feedback(exercise:, selected_option:, correct:)
    prepare_rhythm_playground!

    if correct
      store_new_rhythm_exercise!(preferences)
      @rhythm_exercise = current_rhythm_exercise
    else
      @rhythm_exercise = exercise
    end

    if turbo_frame_request?
      render_rhythm_playground_frame
    else
      flash[:playground_feedback] = @playground_feedback
      redirect_to app_playground_path(activity: "ritmica", **preferences)
    end
  end

  def compact_reading_exercise_storage(exercise)
    payload = exercise.to_h.deep_symbolize_keys
    option_ids = Array(payload[:options]).filter_map do |option|
      option.is_a?(Hash) ? option[:id] || option["id"] : option.to_s
    end

    {
      "l" => payload[:season_mode],
      "v" => payload[:season_id],
      "m" => payload[:clef_mode],
      "q" => payload[:question_mode],
      "t" => payload[:question_type],
      "c" => payload[:clef_id],
      "p" => payload[:pitch_name],
      "i" => payload[:staff_position_index],
      "a" => payload[:correct_option_id],
      "o" => option_ids,
      "n" => payload[:note_accidental_id],
      "k" => payload[:key_signature_id]
    }.compact
  end

  def compact_harmony_exercise_storage(exercise)
    payload = exercise.to_h.deep_symbolize_keys
    return { "f" => "harmony-register-v1", "p" => payload.except(:assignment_id, :attempt_token).deep_stringify_keys } if payload.key?(:register_version)
    return { "f" => payload[:difficulty_version], "p" => payload.except(:assignment_id, :attempt_token).deep_stringify_keys } if payload.key?(:difficulty_version)
    option_ids = Array(payload[:options]).filter_map do |option|
      option.is_a?(Hash) ? option[:id] || option["id"] : option.to_s.presence
    end

    {
      "m" => payload[:question_mode],
      "s" => payload[:chord_structure],
      "t" => payload[:question_type],
      "k" => payload[:key_id],
      "d" => payload[:chord_degree],
      "i" => payload[:progression_focus_index],
      "a" => payload[:correct_option_id],
      "o" => option_ids,
      "p" => payload[:progression_template_id]
    }.compact
  end

  def compact_rhythm_exercise_storage(exercise)
    payload = exercise.to_h.deep_symbolize_keys
    if payload.key?(:rhythm_format)
      return { "f" => payload[:rhythm_format], "p" => payload.except(:assignment_id, :attempt_token).deep_stringify_keys }
    end
    option_ids = Array(payload[:options]).filter_map do |option|
      option.is_a?(Hash) ? option[:id] || option["id"] : option.to_s.presence
    end

    {
      "m" => payload[:activity_mode],
      "b" => payload[:tempo_bpm],
      "a" => payload[:correct_option_id],
      "o" => option_ids
    }.compact
  end

  def reading_playground_state
    @reading_playground_state ||= begin
      state = read_reading_playground_state
      migrate_legacy_reading_playground_state!(state)
    end
  end

  def read_reading_playground_state
    stored = reading_playground_store.read(reading_playground_state_cache_key)
    stored.is_a?(Hash) ? stored.deep_symbolize_keys : {}
  end

  def write_reading_playground_state(updates)
    normalized_updates = updates.deep_symbolize_keys
    state = reading_playground_state.merge(normalized_updates)
    reading_playground_store.write(
      reading_playground_state_cache_key,
      state.deep_stringify_keys,
      expires_in: 12.hours
    )
    @reading_playground_state = state
  end

  def migrate_legacy_reading_playground_state!(state)
    migrated_state = state.deep_dup
    legacy_exercise = session.delete(:reading_note_exercise)&.to_h
    legacy_previous_exercise = session.delete(:reading_previous_note_exercise)&.to_h
    legacy_previous_answered = session.delete(:reading_previous_note_exercise_answered)
    legacy_recent_exercises = Array(session.delete(:reading_recent_exercises)).map { |entry| entry.to_h }
    legacy_scoreboard = session.delete(:reading_scoreboard)&.to_h
    changed = false

    if migrated_state[:exercise].blank? && legacy_exercise.present?
      compact_exercise = normalize_reading_exercise_storage(legacy_exercise)
      if compact_exercise.present?
        migrated_state[:exercise] = compact_exercise
        changed = true
      end
    end

    if migrated_state[:previous_exercise].blank? && legacy_previous_exercise.present?
      compact_exercise = normalize_reading_exercise_storage(legacy_previous_exercise)
      if compact_exercise.present?
        migrated_state[:previous_exercise] = compact_exercise
        changed = true
      end
    end

    if migrated_state[:previous_exercise_answered].nil? && !legacy_previous_answered.nil?
      migrated_state[:previous_exercise_answered] = legacy_previous_answered == true
      changed = true
    end

    if migrated_state[:recent_exercises].blank? && legacy_recent_exercises.present?
      migrated_state[:recent_exercises] = legacy_recent_exercises
      changed = true
    end

    if migrated_state[:scoreboard].blank? && legacy_scoreboard.present?
      migrated_state[:scoreboard] = legacy_scoreboard
      changed = true
    end

    if changed
      reading_playground_store.write(
        reading_playground_state_cache_key,
        migrated_state.deep_stringify_keys,
        expires_in: 12.hours
      )
    end

    migrated_state
  end

  def reading_playground_store
    return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

    READING_PLAYGROUND_STATE_FALLBACK_STORE
  end

  def reading_playground_state_cache_key
    token = session[:reading_playground_state_token]
    token = SecureRandom.hex(16) if token.blank?
    session[:reading_playground_state_token] = token
    "playground:leitura:#{current_user.id}:#{token}"
  end

  def next_reading_recent_exercises(exercise)
    recent = reading_recent_exercises
    recent << {
      clef_id: exercise[:clef_id],
      question_type: exercise[:question_type],
      season_id: exercise[:season_id],
      staff_position_index: exercise[:staff_position_index],
      note_accidental_id: exercise[:note_accidental_id],
      key_signature_id: exercise[:key_signature_id]
    }
    recent.last(24).map(&:stringify_keys)
  end

  def harmony_playground_state
    @harmony_playground_state ||= begin
      state = read_harmony_playground_state
      migrate_legacy_harmony_playground_state!(state)
    end
  end

  def read_harmony_playground_state
    stored = harmony_playground_store.read(harmony_playground_state_cache_key)
    stored.is_a?(Hash) ? stored.deep_symbolize_keys : {}
  end

  def write_harmony_playground_state(updates)
    state = harmony_playground_state.merge(updates.deep_symbolize_keys)
    harmony_playground_store.write(
      harmony_playground_state_cache_key,
      state.deep_stringify_keys,
      expires_in: 12.hours
    )
    @harmony_playground_state = state
  end

  def migrate_legacy_harmony_playground_state!(state)
    migrated_state = state.deep_dup
    legacy_exercise = session.delete(:harmony_exercise)&.to_h
    legacy_recent_exercises = Array(session.delete(:harmony_recent_exercises)).map { |entry| entry.to_h }
    legacy_scoreboard = session.delete(:harmony_scoreboard)&.to_h
    changed = false

    if migrated_state[:exercise].blank? && legacy_exercise.present?
      compact_exercise = normalize_harmony_exercise_storage(legacy_exercise)
      if compact_exercise.present?
        migrated_state[:exercise] = compact_exercise
        changed = true
      end
    end

    if migrated_state[:recent_exercises].blank? && legacy_recent_exercises.present?
      migrated_state[:recent_exercises] = legacy_recent_exercises
      changed = true
    end

    if migrated_state[:scoreboard].blank? && legacy_scoreboard.present?
      migrated_state[:scoreboard] = legacy_scoreboard
      changed = true
    end

    if changed
      harmony_playground_store.write(
        harmony_playground_state_cache_key,
        migrated_state.deep_stringify_keys,
        expires_in: 12.hours
      )
    end

    migrated_state
  end

  def harmony_playground_store
    return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

    HARMONY_PLAYGROUND_STATE_FALLBACK_STORE
  end

  def harmony_playground_state_cache_key
    token = session[:harmony_playground_state_token]
    token = SecureRandom.hex(16) if token.blank?
    session[:harmony_playground_state_token] = token
    "playground:harmonia:#{current_user.id}:#{token}"
  end

  def next_harmony_recent_exercises(exercise)
    recent = harmony_recent_exercises
    recent << {
      question_type: exercise[:question_type],
      key_id: exercise[:key_id],
      chord_structure: exercise[:chord_structure],
      degree: exercise[:chord_degree],
      progression_template_id: exercise[:progression_template_id],
      progression_focus_index: exercise[:progression_focus_index]
    }
    recent.last(6).map(&:stringify_keys)
  end

  def rhythm_playground_state
    @rhythm_playground_state ||= read_rhythm_playground_state
  end

  def read_rhythm_playground_state
    stored = rhythm_playground_store.read(rhythm_playground_state_cache_key)
    stored.is_a?(Hash) ? stored.deep_symbolize_keys : {}
  end

  def write_rhythm_playground_state(updates)
    state = rhythm_playground_state.merge(updates.deep_symbolize_keys)
    rhythm_playground_store.write(
      rhythm_playground_state_cache_key,
      state.deep_stringify_keys,
      expires_in: 12.hours
    )
    @rhythm_playground_state = state
  end

  def rhythm_playground_store
    return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

    RHYTHM_PLAYGROUND_STATE_FALLBACK_STORE
  end

  def rhythm_playground_state_cache_key
    token = session[:rhythm_playground_state_token]
    token = SecureRandom.hex(16) if token.blank?
    session[:rhythm_playground_state_token] = token
    "playground:ritmica:#{current_user.id}:#{token}"
  end

  def next_rhythm_recent_exercises(exercise)
    recent = rhythm_recent_exercises
    recent << {
      activity_mode: exercise[:activity_mode],
      meter_id: exercise[:meter_id],
      signature: exercise[:correct_option_id]
    }
    recent.last(6).map(&:stringify_keys)
  end

  def normalize_reading_exercise_storage(payload)
    payload = payload.to_h.stringify_keys
    option_ids = Array(payload["o"] || payload["options"]).filter_map do |option|
      option.is_a?(Hash) ? option["id"] || option[:id] : option.to_s.presence
    end

    compact_payload = {
      "l" => payload["l"] || payload["season_mode"] || ReadingNoteExerciseGenerator::DEFAULT_SEASON_MODE,
      "v" => payload["v"] || payload["season_id"] || ReadingNoteExerciseGenerator::DEFAULT_SEASON_ID,
      "m" => payload["m"] || payload["clef_mode"],
      "q" => payload["q"] || payload["question_mode"],
      "t" => payload["t"] || payload["question_type"],
      "c" => payload["c"] || payload["clef_id"],
      "p" => payload["p"] || payload["pitch_name"],
      "i" => payload["i"] || payload["staff_position_index"],
      "a" => payload["a"] || payload["correct_option_id"],
      "o" => option_ids,
      "n" => payload["n"] || payload["note_accidental_id"],
      "k" => payload["k"] || payload["key_signature_id"]
    }.compact

    required_keys = %w[l v m q t c a o]
    return if required_keys.any? { |key| compact_payload[key].blank? }
    return if %w[note_name accidental].include?(compact_payload["t"]) && %w[p i].any? { |key| compact_payload[key].blank? }
    return if compact_payload["t"] == "key_signature" && compact_payload["k"].blank?

    compact_payload
  end

  def normalize_harmony_exercise_storage(payload)
    payload = payload.to_h.stringify_keys
    if payload.key?("f")
      return unless %w[harmony-levels-v1 harmony-register-v1].include?(payload["f"]) && payload["p"].is_a?(Hash)
      return { "f" => payload["f"], "p" => payload["p"].deep_stringify_keys }
    end
    option_ids = Array(payload["o"] || payload["options"]).filter_map do |option|
      option.is_a?(Hash) ? option["id"] || option[:id] : option.to_s.presence
    end

    compact_payload = {
      "m" => payload["m"] || payload["question_mode"],
      "s" => payload["s"] || payload["chord_structure"],
      "t" => payload["t"] || payload["question_type"],
      "k" => payload["k"] || payload["key_id"],
      "d" => payload["d"] || payload["chord_degree"],
      "i" => payload["i"] || payload["progression_focus_index"],
      "a" => payload["a"] || payload["correct_option_id"],
      "o" => option_ids,
      "p" => payload["p"] || payload["progression_template_id"]
    }.compact

    required_keys = %w[m s t k a o]
    return if required_keys.any? { |key| compact_payload[key].blank? }
    return if %w[quality scale_degree harmonic_function].include?(compact_payload["t"]) && compact_payload["d"].blank?
    return if compact_payload["t"] == "progression" && %w[d i p].any? { |key| compact_payload[key].blank? }

    compact_payload
  end

  def normalize_rhythm_exercise_storage(payload)
    payload = payload.to_h.stringify_keys
    if payload.key?("f")
      return unless payload["f"] == "meter-v1" && payload["p"].is_a?(Hash)
      return { "f" => payload["f"], "p" => payload["p"].deep_stringify_keys }
    end
    option_ids = Array(payload["o"] || payload["options"]).filter_map do |option|
      option.is_a?(Hash) ? option["id"] || option[:id] : option.to_s.presence
    end

    compact_payload = {
      "m" => payload["m"] || payload["activity_mode"],
      "b" => payload["b"] || payload["tempo_bpm"],
      "a" => payload["a"] || payload["correct_option_id"],
      "o" => option_ids
    }.compact

    required_keys = %w[m b a o]
    return if required_keys.any? { |key| compact_payload[key].blank? }

    compact_payload
  end

  def hydrate_reading_exercise(payload)
    validated_hydration("leitura") { hydrate_reading_exercise_payload(payload) }
  end

  def hydrate_reading_exercise_payload(payload)
    season_mode = payload.fetch("l")
    season_id = payload.fetch("v")
    clef_mode = payload.fetch("m")
    question_mode = payload.fetch("q")
    question_type = payload.fetch("t")
    clef_id = payload.fetch("c")
    correct_option_id = payload.fetch("a")
    option_ids = payload.fetch("o")
    pitch_name = payload["p"]
    staff_position_index = payload["i"]&.to_i
    note_accidental_id = payload["n"]
    key_signature_id = payload["k"]

    clef_definition = ReadingNoteExerciseGenerator.clef_definition(clef_id)
    season_mode_definition = ReadingNoteExerciseGenerator.season_mode_definition(season_mode)
    season_definition = ReadingNoteExerciseGenerator.season_definition(season_id)
    clef_mode_definition = ReadingNoteExerciseGenerator.clef_mode_definition(clef_mode)
    question_mode_definition = ReadingNoteExerciseGenerator.question_mode_definition(question_mode)
    question_type_definition = ReadingNoteExerciseGenerator.question_type_definition(question_type)
    return if clef_definition.blank? || season_mode_definition.blank? || season_definition.blank? || clef_mode_definition.blank? || question_mode_definition.blank? || question_type_definition.blank?

    options = build_reading_options(option_ids:, question_type:)
    return if options.size != 4 || options.none? { |option| option[:id] == correct_option_id }

    base_exercise = {
      season_mode:,
      season_mode_label: season_mode_definition[:label],
      season_id:,
      season_label: season_definition[:label],
      season_topics: season_definition[:topics],
      question_mode:,
      question_mode_label: question_mode_definition[:label],
      question_type:,
      question_type_label: question_type_definition[:label],
      clef_mode:,
      clef_mode_label: clef_mode_definition[:label],
      clef_id:,
      clef_label: clef_definition[:label],
      clef_symbol: clef_definition[:symbol],
      clef_symbol_label: clef_definition[:symbol_label],
      head_music_clef: clef_definition[:head_music],
      correct_option_id:,
      options:
    }

    case question_type
    when "note_name"
      correct_option = ReadingNoteExerciseGenerator.note_option(correct_option_id)
      return if correct_option.blank? || pitch_name.blank? || staff_position_index.blank?

      base_exercise.merge(
        question: "Observe a pauta e identifique a nota escrita.",
        staff_position_index:,
        pitch_name:,
        pitch_label: ReadingNoteExerciseGenerator.localize_pitch_name(pitch_name),
        correct_option_label: correct_option[:label],
        signature: ReadingNoteExerciseGenerator.exercise_signature(question_type:, clef_id:, pitch_name:),
        notation_kind: "note"
      )
    when "accidental"
      correct_option = ReadingNoteExerciseGenerator.accidental_note_option(correct_option_id)
      note_accidental = ReadingNoteExerciseGenerator.accidental_definition(note_accidental_id)
      return if correct_option.blank? || note_accidental.blank? || pitch_name.blank? || staff_position_index.blank?

      base_exercise.merge(
        question: "Observe a nota na pauta e identifique a nota completa com o acidente musical indicado.",
        staff_position_index:,
        pitch_name:,
        pitch_label: ReadingNoteExerciseGenerator.localize_pitch_name(pitch_name),
        note_accidental_id:,
        note_accidental_label: note_accidental[:label],
        note_accidental_symbol: note_accidental[:symbol],
        correct_option_label: correct_option[:label],
        signature: ReadingNoteExerciseGenerator.exercise_signature(question_type:, clef_id:, pitch_name:, accidental_id: note_accidental_id),
        notation_kind: "note"
      )
    when "key_signature"
      correct_option = ReadingNoteExerciseGenerator.key_signature_definition(correct_option_id)
      return if correct_option.blank? || key_signature_id.blank?

      base_exercise.merge(
        question: "Observe a armadura de clave e identifique a tonalidade maior correspondente.",
        key_signature_id:,
        key_signature_label: correct_option[:label],
        key_signature_accidentals: ReadingNoteExerciseGenerator.key_signature_accidentals_for(clef_id, key_signature_id),
        correct_option_label: correct_option[:label],
        signature: ReadingNoteExerciseGenerator.exercise_signature(question_type:, clef_id:, key_signature_id:),
        notation_kind: "key_signature"
      )
    end
  end

  def hydrate_harmony_exercise(payload)
    validated_hydration("harmonia") { hydrate_harmony_exercise_payload(payload) }
  end

  def hydrate_harmony_exercise_payload(payload)
    return payload.fetch("p").deep_symbolize_keys if %w[harmony-levels-v1 harmony-register-v1].include?(payload["f"])
    question_mode = payload.fetch("m")
    chord_structure = payload.fetch("s")
    question_type = payload.fetch("t")
    key_id = payload.fetch("k")
    correct_option_id = payload.fetch("a")
    option_ids = payload.fetch("o")
    chord_degree = payload["d"]&.to_i
    progression_focus_index = payload["i"]&.to_i
    progression_template_id = payload["p"]

    question_mode_definition = HarmonyExerciseGenerator.question_mode_definition(question_mode)
    chord_structure_definition = HarmonyExerciseGenerator.chord_structure_definition(chord_structure)
    key_definition = HarmonyExerciseGenerator.key_definition(key_id)
    return if question_mode_definition.blank? || chord_structure_definition.blank? || key_definition.blank?

    generator = HarmonyExerciseGenerator.new(question_mode:, chord_structure:)
    chord = generator.send(:chord_for_degree, key_definition:, degree: chord_degree) if chord_degree.present?
    options = build_harmony_options(question_type:, key_definition:, chord_structure:, option_ids:, generator:)
    return if options.size != 4 || options.none? { |option| option[:id] == correct_option_id }

    base_exercise = {
      question_mode:,
      question_mode_label: question_mode_definition[:label],
      chord_structure:,
      chord_structure_label: chord_structure_definition[:label],
      question_type:,
      question_type_label: HarmonyExerciseGenerator.question_type_label(question_type, chord_structure),
      key_id:,
      key_label: key_definition[:label],
      correct_option_id:,
      options:
    }

    case question_type
    when "quality", "scale_degree", "harmonic_function"
      return if chord.blank?
      reference_chord = %w[scale_degree harmonic_function].include?(question_type) ? generator.send(:chord_for_degree, key_definition:, degree: 1) : nil

      base_exercise.merge(
        question: HarmonyExerciseGenerator.question_prompt(question_type, chord_structure),
        function_convention_id: HarmonicFunctionConvention::VERSION,
        chord_degree: chord[:degree],
        chord_degree_label: chord[:degree_card_label],
        chord_roman: chord[:roman],
        chord_quality_id: chord[:quality_id],
        chord_quality_label: chord[:quality_label],
        chord_notes_label: chord[:notes_label],
        chord_root_label: chord[:root_label],
        chord_function_id: chord[:function_id],
        chord_function_label: chord[:function_label],
        prompt_label: "Escuta",
        prompt_value: harmony_prompt_value(reference_chord:),
        context_items: harmony_context_items(question_type:, key_definition:, chord_structure_definition:, reference_chord:),
        audio_sequence: harmony_audio_sequence(question_type:, chord:, reference_chord:),
        correct_option_label: harmony_correct_label(question_type:, chord:),
        signature: harmony_signature(question_type:, key_id:, chord_structure:, chord:, progression_template_id: nil)
      )
    when "progression"
      template = HarmonyExerciseGenerator.progression_template(progression_template_id)
      return if template.blank? || chord.blank? || progression_focus_index.blank?

      progression_chords = template[:sequence].map do |degree|
        generator.send(:chord_for_degree, key_definition:, degree:)
      end

      base_exercise.merge(
        question: HarmonyExerciseGenerator.progression_question(progression_focus_index),
        progression_template_id:,
        progression_focus_index:,
        chord_degree: chord[:degree],
        chord_degree_label: chord[:degree_card_label],
        chord_roman: chord[:roman],
        chord_quality_id: chord[:quality_id],
        chord_quality_label: chord[:quality_label],
        chord_notes_label: chord[:notes_label],
        chord_root_label: chord[:root_label],
        chord_function_id: chord[:function_id],
        chord_function_label: chord[:function_label],
        prompt_label: "Ponto de escuta",
        prompt_value: ExercisePresentation.progression_prompt(progression_focus_index),
        context_items: [
          { label: "Tonalidade", value: key_definition[:label] },
          { label: "Estrutura", value: chord_structure_definition[:label] },
          { label: "Alvo", value: HarmonyExerciseGenerator.ordinal_label(progression_focus_index) }
        ],
        progression_steps: ExercisePresentation.progression_steps(progression_chords.size, progression_focus_index),
        audio_sequence: progression_chords.map { |entry| harmony_audio_payload(entry) },
        correct_option_label: harmony_degree_option_label(chord),
        signature: harmony_signature(
          question_type:,
          key_id:,
          chord_structure:,
          chord:,
          progression_template_id:,
          progression_focus_index:
        )
      )
    end
  end

  def hydrate_rhythm_exercise(payload)
    validated_hydration("ritmica") { hydrate_rhythm_exercise_payload(payload) }
  end

  def hydrate_rhythm_exercise_payload(payload)
    return payload.fetch("p").deep_symbolize_keys if payload["f"] == "meter-v1"

    activity_mode = payload.fetch("m")
    tempo_bpm = payload.fetch("b").to_i
    correct_option_id = payload.fetch("a")
    option_ids = payload.fetch("o")

    activity_mode_definition = RhythmExerciseGenerator.activity_mode_definition(activity_mode)
    options = option_ids.filter_map { |option_id| RhythmExerciseGenerator.option_from_signature(option_id) }
    correct_option = options.find { |option| option[:id] == correct_option_id }
    return if activity_mode_definition.blank? || tempo_bpm <= 0 || options.size != 4 || correct_option.blank?

    {
      activity_mode:,
      activity_mode_label: activity_mode_definition[:label],
      question: RhythmExerciseGenerator.description_for(activity_mode),
      prompt_label: "Escuta",
      prompt_value: RhythmExerciseGenerator.prompt_value_for(activity_mode),
      focus_label: RhythmExerciseGenerator.focus_label_for(activity_mode),
      tempo_bpm:,
      time_signature_label: "4/4",
      count_in_beats: RhythmExerciseGenerator::BEATS_PER_MEASURE,
      metronome_during_pattern: RhythmExerciseGenerator.metronome_during_pattern?(activity_mode),
      playback_cycles: RhythmExerciseGenerator.playback_cycles_for(activity_mode),
      audio_events: RhythmExerciseGenerator.audio_events_for_signature(correct_option_id),
      correct_option_id:,
      correct_option_label: correct_option[:aria_label],
      options:,
      signature: RhythmExerciseGenerator.exercise_signature(
        activity_mode:,
        pattern_signature: correct_option_id,
        tempo_bpm:
      )
    }
  end

  def build_reading_options(option_ids:, question_type:)
    option_ids.filter_map do |option_id|
      option = case question_type
               when "note_name"
                 ReadingNoteExerciseGenerator.note_option(option_id)
               when "accidental"
                 ReadingNoteExerciseGenerator.accidental_note_option(option_id)
               when "key_signature"
                 ReadingNoteExerciseGenerator.key_signature_definition(option_id)
               end
      next if option.blank?

      { id: option[:id], label: option[:label] }
    end
  end

  def build_harmony_options(question_type:, key_definition:, chord_structure:, option_ids:, generator:)
    option_ids.filter_map do |option_id|
      label = case question_type
              when "quality"
                HarmonyExerciseGenerator.quality_definition(chord_structure, option_id)&.dig(:label)
              when "harmonic_function"
                HarmonyExerciseGenerator.function_definition(option_id)&.dig(:label)
              when "scale_degree"
                degree = option_id.to_i
                generated_chord = generator.send(:chord_for_degree, key_definition:, degree:)
                next if generated_chord.blank?

                harmony_degree_option_label(generated_chord)
              when "progression"
                degree = option_id.to_i
                generated_chord = generator.send(:chord_for_degree, key_definition:, degree:)
                next if generated_chord.blank?

                harmony_degree_option_label(generated_chord)
              end

      next if label.blank?

      { id: option_id.to_s, label: }
    end
  end

  def harmony_context_items(question_type:, key_definition:, chord_structure_definition:, reference_chord: nil)
    focus_value = case question_type
                  when "scale_degree"
                    "Grau do campo harmônico"
                  when "harmonic_function"
                    "Função dentro da tonalidade"
                  else
                    chord_structure_definition[:id] == "tetrad" ? "Qualidade da tétrade" : "Qualidade da tríade"
                  end

    items = [
      { label: "Tonalidade", value: key_definition[:label] },
      { label: "Estrutura", value: chord_structure_definition[:label] },
      { label: "Foco", value: focus_value }
    ]

    items << { label: "Referência", value: "#{reference_chord[:roman]} da tonalidade antes do alvo" } if %w[scale_degree harmonic_function].include?(question_type) && reference_chord.present?

    items
  end

  def harmony_audio_payload(chord)
    {
      label: chord[:roman],
      pitches: chord[:pitches],
      frequencies: chord[:frequencies]
    }
  end

  def harmony_correct_label(question_type:, chord:)
    case question_type
    when "quality"
      chord[:quality_label]
    when "scale_degree"
      "#{chord[:roman]} (#{chord[:degree]}º grau)"
    else
      chord[:function_label]
    end
  end

  def harmony_progression_option_label(chord)
    "#{chord[:roman]} · #{chord[:root_label]} #{chord[:quality_short_label]}"
  end

  def harmony_degree_option_label(chord)
    "#{chord[:roman]} (#{chord[:degree]}º grau)"
  end

  def harmony_audio_sequence(question_type:, chord:, reference_chord:)
    return [harmony_audio_payload(reference_chord), harmony_audio_payload(chord)] if %w[scale_degree harmonic_function].include?(question_type) && reference_chord.present?

    [harmony_audio_payload(chord)]
  end

  def harmony_prompt_value(reference_chord:)
    return "Primeiro #{reference_chord[:roman]}, depois o acorde alvo" if reference_chord.present?

    "Acorde isolado"
  end

  def harmony_signature(question_type:, key_id:, chord_structure:, chord:, progression_template_id:, progression_focus_index: nil)
    parts = [question_type, key_id, chord_structure]
    parts << progression_template_id if progression_template_id.present?
    parts << progression_focus_index if progression_focus_index.present?
    parts << chord[:degree]
    parts << chord[:quality_id] if question_type == "quality"
    parts << chord[:function_id] if question_type == "harmonic_function"
    parts.join("|")
  end
end
