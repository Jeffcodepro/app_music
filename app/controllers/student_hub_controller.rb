class StudentHubController < ApplicationController
  DEFAULT_PLAYGROUND_ACTIVITY = "percepcao".freeze
  HARMONY_PLAYGROUND_STATE_FALLBACK_STORE = ActiveSupport::Cache::MemoryStore.new(expires_in: 12.hours)
  GUIDED_AREA_LABELS = {
    "leitura" => "Estruturação / Leitura",
    "ritmica" => "Rítmica",
    "percepcao" => "Percepção",
    "harmonia" => "Harmonia"
  }.freeze

  GUIDED_EPISODE_TITLES = {
    "leitura" => [
      "Pauta Musical Sem Mistério",
      "Claves na Prática",
      "Figuras e Pausas Essenciais",
      "Leitura Direcionada em Compassos Simples",
      "Leitura Fluida com Frases Curtas",
      "Checkpoint de Leitura Aplicada"
    ],
    "ritmica" => [
      "Pulso e Estabilidade",
      "Semínimas e Colcheias em Movimento",
      "Subdivisão com Metronomo",
      "Compassos Compostos no Dia a Dia",
      "Padrões de Sincopa",
      "Checkpoint de Precisão Rítmica"
    ],
    "percepcao" => [
      "Escuta Ativa e Referência Tonal",
      "Intervalos: uníssono à quinta",
      "Comparação de Frases Melódicas",
      "Reconhecimento de Direção Melódica",
      "Percepção em Duas Vozes",
      "Checkpoint de Audição Contextual"
    ],
    "harmonia" => [
      "Escala Maior e Graus",
      "Tríades: Formação e Qualidade",
      "Campo Harmônico Inicial",
      "Funções Harmônicas em Progressão",
      "Cadências e Resolução",
      "Checkpoint de Harmonia Aplicada"
    ]
  }.freeze

  before_action :authenticate_user!
  layout "platform"

  def trail_show
    @area = params[:area].to_s.presence || "ritmica"
    @level = params[:nivel].to_s.presence || "1"
  end

  def lesson_show
    @lesson_id = params[:id].to_s
    @mode = params[:mode].to_s == "livre" ? "livre" : "guiado"
    return if @mode == "livre"

    @selected_area = select_guided_area
    @selected_area_label = GUIDED_AREA_LABELS[@selected_area]
    @season_number = guided_season_number(current_user, @selected_area)
    @playback_speeds = ["0.75x", "1.0x", "1.25x", "1.5x", "2.0x"]
    @seasons = (1..4).map { |value| "Nível #{value}" }

    @episode_cards = build_episode_cards(@selected_area)
    @content_rows = [
      {
        title: "Episódios da temporada",
        subtitle: "Aulas disponíveis para o seu nível atual.",
        items: @episode_cards
      },
      {
        title: "Próximas aulas",
        subtitle: "Conteúdos que conectam com o que você já estudou.",
        items: @episode_cards.drop(1) + @episode_cards.first(1)
      },
      {
        title: "Revisar depois",
        subtitle: "Seleção para reforçar fundamentos em sessões curtas.",
        items: @episode_cards.reverse
      }
    ]
  end

  def practice_result; end

  def playground
    @playground_activities = helpers.playground_activity_catalog
    @selected_activity = helpers.playground_activity_for(params[:activity]) || helpers.playground_activity_for(DEFAULT_PLAYGROUND_ACTIVITY)
    @playground_feedback = flash[:playground_feedback]&.to_h&.deep_symbolize_keys
    @playground_feedback = nil if @playground_feedback.present? && @playground_feedback[:activity] != @selected_activity[:slug]
    @perception_autoplay = params[:autoplay].present?

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
    when "harmonia"
      submit_harmony_playground_answer
    else
      redirect_to app_playground_path(activity: params[:activity].presence || DEFAULT_PLAYGROUND_ACTIVITY),
                  alert: "Esse playground ainda está em construção."
    end
  end

  def submit_perception_playground_answer
    exercise = current_perception_exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "percepcao", refresh: 1, **perception_preferences),
                  alert: "Gere um novo intervalo antes de responder."
      return
    end

    preferences = perception_preferences
    exercise_signature = params[:exercise_signature].to_s
    if exercise_signature.present? && exercise_signature != exercise[:signature].to_s
      @playground_feedback = {
        activity: "percepcao",
        correct: false,
        synchronization_error: true
      }
      prepare_perception_playground!
      @perception_exercise = exercise

      if turbo_frame_request?
        render_perception_playground_frame
      else
        flash[:playground_feedback] = @playground_feedback
        redirect_to app_playground_path(activity: "percepcao", **preferences)
      end
      return
    end

    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = selected_option_id == exercise[:correct_option_id]

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

  def select_guided_area
    requested_area = params[:area].to_s
    return requested_area if GUIDED_AREA_LABELS.key?(requested_area)

    lesson_area = @lesson_id[%r{(leitura|ritmica|percepcao|harmonia)}, 1]
    return lesson_area if GUIDED_AREA_LABELS.key?(lesson_area)

    area_counts = current_user.study_activities.where(area: GUIDED_AREA_LABELS.keys).group(:area).count
    most_practiced = area_counts.max_by { |_area, count| count }&.first
    GUIDED_AREA_LABELS.key?(most_practiced) ? most_practiced : "leitura"
  end

  def guided_season_number(user, area)
    activity_count = user.study_activities.where(area: area).count

    case activity_count
    when 0..5 then 1
    when 6..14 then 2
    when 15..29 then 3
    else 4
    end
  end

  def build_episode_cards(area)
    titles = GUIDED_EPISODE_TITLES.fetch(area)

    titles.each_with_index.map do |title, index|
      {
        number: index + 1,
        title: title,
        duration: "#{10 + index} min",
        progress: [[20 + (index * 13), 95].min, 100].min
      }
    end
  end

  def current_perception_exercise
    session[:perception_interval_exercise]&.to_h&.deep_symbolize_keys
  end

  def current_reading_exercise
    stored_exercise = session[:reading_note_exercise]&.to_h
    return if stored_exercise.blank?

    compact_exercise = normalize_reading_exercise_storage(stored_exercise)
    return if compact_exercise.blank?

    session[:reading_note_exercise] = compact_exercise if stored_exercise != compact_exercise
    hydrate_reading_exercise(compact_exercise)
  end

  def current_harmony_exercise
    stored_exercise = harmony_playground_state[:exercise]&.to_h&.stringify_keys
    return if stored_exercise.blank?

    compact_exercise = normalize_harmony_exercise_storage(stored_exercise)
    return if compact_exercise.blank?

    write_harmony_playground_state(exercise: compact_exercise) if stored_exercise != compact_exercise
    hydrate_harmony_exercise(compact_exercise)
  end

  def prepare_perception_playground!
    @perception_instruments = PerceptionIntervalExerciseGenerator.instruments
    @perception_direction_modes = PerceptionIntervalExerciseGenerator.direction_modes
    @perception_preferences = perception_preferences
    @perception_scoreboard = perception_scoreboard
  end

  def prepare_reading_playground!
    @reading_clef_modes = ReadingNoteExerciseGenerator.clef_modes
    @reading_question_modes = ReadingNoteExerciseGenerator.question_modes
    @reading_preferences = reading_preferences
    @reading_scoreboard = reading_scoreboard
  end

  def prepare_harmony_playground!
    @harmony_question_modes = HarmonyExerciseGenerator.question_modes
    @harmony_chord_structures = HarmonyExerciseGenerator.chord_structures
    @harmony_instruments = PerceptionIntervalExerciseGenerator.instruments
    @harmony_preferences = harmony_preferences
    @harmony_scoreboard = harmony_scoreboard
  end

  def should_refresh_perception_exercise?
    return true if params[:refresh].present?
    return true if current_perception_exercise.blank?

    exercise = current_perception_exercise
    exercise[:instrument] != @perception_preferences[:instrument] || exercise[:direction_mode] != @perception_preferences[:direction_mode]
  end

  def should_refresh_reading_exercise?
    return true if params[:refresh].present?
    return true if current_reading_exercise.blank?

    current_reading_exercise[:clef_mode] != @reading_preferences[:clef_mode] ||
      current_reading_exercise[:question_mode] != @reading_preferences[:question_mode]
  end

  def should_refresh_harmony_exercise?
    return true if params[:refresh].present?
    return true if current_harmony_exercise.blank?

    current_harmony_exercise[:question_mode] != @harmony_preferences[:question_mode] ||
      current_harmony_exercise[:chord_structure] != @harmony_preferences[:chord_structure]
  end

  def store_new_perception_exercise!(preferences = perception_preferences)
    exercise = PerceptionIntervalExerciseGenerator.new(
      direction_mode: preferences[:direction_mode],
      instrument: preferences[:instrument],
      recent_exercises: perception_recent_exercises
    ).call

    session[:perception_interval_exercise] = exercise.deep_stringify_keys
    store_recent_perception_exercise!(exercise)
  end

  def store_new_reading_exercise!(preferences = reading_preferences)
    exercise = ReadingNoteExerciseGenerator.new(
      clef_mode: preferences[:clef_mode],
      question_mode: preferences[:question_mode],
      recent_exercises: reading_recent_exercises
    ).call

    session[:reading_note_exercise] = compact_reading_exercise_storage(exercise)
    store_recent_reading_exercise!(exercise)
  end

  def store_new_harmony_exercise!(preferences = harmony_preferences)
    exercise = HarmonyExerciseGenerator.new(
      question_mode: preferences[:question_mode],
      chord_structure: preferences[:chord_structure],
      recent_exercises: harmony_recent_exercises
    ).call

    write_harmony_playground_state(
      exercise: compact_harmony_exercise_storage(exercise),
      recent_exercises: next_harmony_recent_exercises(exercise)
    )
  end

  def build_perception_playground_feedback(exercise:, selected_option:, correct:)
    {
      activity: "percepcao",
      correct:,
      selected_label: selected_option&.dig(:label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      direction_label: exercise[:direction_label],
      notes: localized_pitch_pair(exercise[:reference_pitch], exercise[:target_pitch]),
      answered: true
    }
  end

  def build_reading_playground_feedback(exercise:, selected_option:, correct:)
    {
      activity: "leitura",
      correct:,
      selected_label: selected_option&.dig(:label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      question_type_label: exercise[:question_type_label],
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

  def record_perception_playground_attempt!(correct:)
    current_user.study_activities.create!(
      area: "percepcao",
      xp_earned: correct ? 20 : 6,
      minutes_practiced: 3,
      occurred_on: Date.current
    )

    scoreboard = perception_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    session[:perception_scoreboard] = scoreboard.stringify_keys
  end

  def record_reading_playground_attempt!(correct:)
    current_user.study_activities.create!(
      area: "leitura",
      xp_earned: correct ? 20 : 6,
      minutes_practiced: 3,
      occurred_on: Date.current
    )

    scoreboard = reading_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    session[:reading_scoreboard] = scoreboard.stringify_keys
  end

  def record_harmony_playground_attempt!(correct:)
    current_user.study_activities.create!(
      area: "harmonia",
      xp_earned: correct ? 20 : 6,
      minutes_practiced: 3,
      occurred_on: Date.current
    )

    scoreboard = harmony_scoreboard
    key = correct ? :correct_count : :incorrect_count
    scoreboard[key] += 1
    write_harmony_playground_state(scoreboard: scoreboard.stringify_keys)
  end

  def perception_preferences
    {
      instrument: sanitize_perception_instrument(params[:instrument]),
      direction_mode: sanitize_perception_direction_mode(params[:direction_mode])
    }
  end

  def reading_preferences
    {
      clef_mode: sanitize_reading_clef_mode(params[:clef_mode]),
      question_mode: sanitize_reading_question_mode(params[:question_mode])
    }
  end

  def harmony_preferences
    {
      question_mode: sanitize_harmony_question_mode(params[:question_mode]),
      chord_structure: sanitize_harmony_chord_structure(params[:chord_structure]),
      instrument: sanitize_harmony_instrument(params[:instrument])
    }
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
    stored = session[:reading_scoreboard]&.to_h || {}
    {
      correct_count: stored["correct_count"].to_i,
      incorrect_count: stored["incorrect_count"].to_i
    }
  end

  def harmony_scoreboard
    stored = harmony_playground_state[:scoreboard].to_h
    {
      correct_count: (stored[:correct_count] || stored["correct_count"]).to_i,
      incorrect_count: (stored[:incorrect_count] || stored["incorrect_count"]).to_i
    }
  end

  def perception_recent_exercises
    Array(session[:perception_recent_exercises]).map { |entry| entry.to_h.symbolize_keys }
  end

  def reading_recent_exercises
    Array(session[:reading_recent_exercises]).filter_map do |entry|
      payload = entry.to_h.stringify_keys
      clef_id = payload["c"] || payload["clef_id"]
      signature = payload["s"] || payload["signature"]
      staff_position_index = payload["p"] || payload["staff_position_index"]
      question_type = payload["t"] || payload["question_type"]

      next if clef_id.blank? || signature.blank?

      {
        clef_id:,
        signature:,
        question_type:,
        staff_position_index: staff_position_index.presence&.to_i
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

  def store_recent_perception_exercise!(exercise)
    recent = perception_recent_exercises
    recent << {
      interval_id: exercise[:correct_option_id],
      signature: exercise[:signature]
    }
    session[:perception_recent_exercises] = recent.last(4).map(&:stringify_keys)
  end

  def store_recent_reading_exercise!(exercise)
    recent = reading_recent_exercises
    recent << {
      clef_id: exercise[:clef_id],
      signature: exercise[:signature],
      question_type: exercise[:question_type],
      staff_position_index: exercise[:staff_position_index]
    }
    session[:reading_recent_exercises] = recent.last(6).map do |entry|
      {
        "c" => entry[:clef_id],
        "s" => entry[:signature],
        "t" => entry[:question_type],
        "p" => entry[:staff_position_index]
      }
    end
  end

  def store_recent_harmony_exercise!(exercise)
    write_harmony_playground_state(recent_exercises: next_harmony_recent_exercises(exercise))
  end

  def clear_perception_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    if params[:refresh].present? || params[:instrument].present? || params[:direction_mode].present?
      @playground_feedback = nil
      @perception_autoplay = false if params[:instrument].present? || params[:direction_mode].present?
    end
  end

  def clear_reading_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    @playground_feedback = nil if params[:refresh].present? || params[:clef_mode].present? || params[:question_mode].present?
  end

  def clear_harmony_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    @playground_feedback = nil if params[:refresh].present? || params[:question_mode].present? || params[:chord_structure].present? || params[:instrument].present?
  end

  def submit_reading_playground_answer
    exercise = current_reading_exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "leitura", refresh: 1, **reading_preferences),
                  alert: "Gere uma nova nota antes de responder."
      return
    end

    preferences = reading_preferences
    exercise_signature = params[:exercise_signature].to_s
    if exercise_signature.present? && exercise_signature != exercise[:signature].to_s
      @playground_feedback = {
        activity: "leitura",
        correct: false,
        synchronization_error: true
      }
      prepare_reading_playground!
      @reading_exercise = exercise

      if turbo_frame_request?
        render_reading_playground_frame
      else
        flash[:playground_feedback] = @playground_feedback
        redirect_to app_playground_path(activity: "leitura", **preferences)
      end
      return
    end

    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = selected_option_id == exercise[:correct_option_id]

    record_reading_playground_attempt!(correct:)
    @playground_feedback = build_reading_playground_feedback(exercise:, selected_option:, correct:)
    prepare_reading_playground!

    if correct
      store_new_reading_exercise!(preferences)
      @reading_exercise = current_reading_exercise
    else
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
    exercise = current_harmony_exercise
    if exercise.blank?
      redirect_to app_playground_path(activity: "harmonia", refresh: 1, **harmony_preferences),
                  alert: "Gere um novo exercício de harmonia antes de responder."
      return
    end

    preferences = harmony_preferences
    exercise_signature = params[:exercise_signature].to_s
    if exercise_signature.present? && exercise_signature != exercise[:signature].to_s
      @playground_feedback = {
        activity: "harmonia",
        correct: false,
        synchronization_error: true
      }
      prepare_harmony_playground!
      @harmony_exercise = exercise

      if turbo_frame_request?
        render_harmony_playground_frame
      else
        flash[:playground_feedback] = @playground_feedback
        redirect_to app_playground_path(activity: "harmonia", **preferences)
      end
      return
    end

    selected_option_id = params[:selected_option_id].to_s
    selected_option = exercise[:options].find { |option| option[:id] == selected_option_id }
    correct = selected_option_id == exercise[:correct_option_id]

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

  def compact_reading_exercise_storage(exercise)
    payload = exercise.to_h.deep_symbolize_keys
    option_ids = Array(payload[:options]).filter_map do |option|
      option.is_a?(Hash) ? option[:id] || option["id"] : option.to_s
    end

    {
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

  def normalize_reading_exercise_storage(payload)
    payload = payload.to_h.stringify_keys
    option_ids = Array(payload["o"] || payload["options"]).filter_map do |option|
      option.is_a?(Hash) ? option["id"] || option[:id] : option.to_s.presence
    end

    compact_payload = {
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

    required_keys = %w[m q t c a o]
    return if required_keys.any? { |key| compact_payload[key].blank? }
    return if %w[note_name accidental].include?(compact_payload["t"]) && %w[p i].any? { |key| compact_payload[key].blank? }
    return if compact_payload["t"] == "key_signature" && compact_payload["k"].blank?

    compact_payload
  end

  def normalize_harmony_exercise_storage(payload)
    payload = payload.to_h.stringify_keys
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

  def hydrate_reading_exercise(payload)
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
    clef_mode_definition = ReadingNoteExerciseGenerator.clef_mode_definition(clef_mode)
    question_mode_definition = ReadingNoteExerciseGenerator.question_mode_definition(question_mode)
    question_type_definition = ReadingNoteExerciseGenerator.question_type_definition(question_type)
    return if clef_definition.blank? || clef_mode_definition.blank? || question_mode_definition.blank? || question_type_definition.blank?

    options = build_reading_options(option_ids:, question_type:)
    return if options.size != 4 || options.none? { |option| option[:id] == correct_option_id }

    base_exercise = {
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
      correct_option = ReadingNoteExerciseGenerator.accidental_definition(correct_option_id)
      note_accidental = ReadingNoteExerciseGenerator.accidental_definition(note_accidental_id)
      return if correct_option.blank? || note_accidental.blank? || pitch_name.blank? || staff_position_index.blank?

      base_exercise.merge(
        question: "Observe a nota na pauta e identifique o acidente musical indicado.",
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
        prompt_value: "Qual grau apareceu na #{HarmonyExerciseGenerator.ordinal_label(progression_focus_index)}?",
        context_items: [
          { label: "Tonalidade", value: key_definition[:label] },
          { label: "Estrutura", value: chord_structure_definition[:label] },
          { label: "Alvo", value: HarmonyExerciseGenerator.ordinal_label(progression_focus_index) }
        ],
        progression_steps: progression_chords.map.with_index(1) do |_entry, position|
          {
            roman: HarmonyExerciseGenerator.ordinal_label(position),
            notes: position == progression_focus_index ? "Responda esta posição" : "Memorize o acorde ouvido",
            focus: position == progression_focus_index
          }
        end,
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

  def build_reading_options(option_ids:, question_type:)
    option_ids.filter_map do |option_id|
      option = case question_type
               when "note_name"
                 ReadingNoteExerciseGenerator.note_option(option_id)
               when "accidental"
                 ReadingNoteExerciseGenerator.accidental_definition(option_id)
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
