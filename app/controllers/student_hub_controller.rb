class StudentHubController < ApplicationController
  DEFAULT_PLAYGROUND_ACTIVITY = "percepcao".freeze
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
    end
  end

  def submit_playground_answer
    selected_activity = helpers.playground_activity_for(params[:activity])

    case selected_activity&.dig(:slug)
    when "percepcao"
      submit_perception_playground_answer
    when "leitura"
      submit_reading_playground_answer
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
end
