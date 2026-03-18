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
    @perception_autoplay = params[:autoplay].present?
    return unless @selected_activity[:slug] == "percepcao"

    prepare_perception_playground!
    clear_perception_feedback_if_starting_new_round!
    store_new_perception_exercise! if should_refresh_perception_exercise?
    @perception_exercise = current_perception_exercise
  end

  def submit_playground_answer
    selected_activity = helpers.playground_activity_for(params[:activity])
    unless selected_activity&.dig(:slug) == "percepcao"
      redirect_to app_playground_path(activity: params[:activity].presence || DEFAULT_PLAYGROUND_ACTIVITY),
                  alert: "Esse playground ainda está em construção."
      return
    end

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

    record_playground_attempt!(correct:)
    @playground_feedback = build_playground_feedback(exercise:, selected_option:, correct:)
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

  def prepare_perception_playground!
    @perception_instruments = PerceptionIntervalExerciseGenerator.instruments
    @perception_direction_modes = PerceptionIntervalExerciseGenerator.direction_modes
    @perception_preferences = perception_preferences
    @perception_scoreboard = perception_scoreboard
  end

  def should_refresh_perception_exercise?
    return true if params[:refresh].present?
    return true if current_perception_exercise.blank?

    exercise = current_perception_exercise
    exercise[:instrument] != @perception_preferences[:instrument] || exercise[:direction_mode] != @perception_preferences[:direction_mode]
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

  def build_playground_feedback(exercise:, selected_option:, correct:)
    {
      correct:,
      selected_label: selected_option&.dig(:label) || "Resposta inválida",
      correct_label: exercise[:correct_option_label],
      direction_label: exercise[:direction_label],
      notes: localized_pitch_pair(exercise[:reference_pitch], exercise[:target_pitch]),
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

  def record_playground_attempt!(correct:)
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

  def perception_preferences
    {
      instrument: sanitize_perception_instrument(params[:instrument]),
      direction_mode: sanitize_perception_direction_mode(params[:direction_mode])
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

  def perception_recent_exercises
    Array(session[:perception_recent_exercises]).map { |entry| entry.to_h.symbolize_keys }
  end

  def store_recent_perception_exercise!(exercise)
    recent = perception_recent_exercises
    recent << {
      interval_id: exercise[:correct_option_id],
      signature: exercise[:signature]
    }
    session[:perception_recent_exercises] = recent.last(4).map(&:stringify_keys)
  end

  def clear_perception_feedback_if_starting_new_round!
    return if @playground_feedback.present?

    if params[:refresh].present? || params[:instrument].present? || params[:direction_mode].present?
      @playground_feedback = nil
      @perception_autoplay = false if params[:instrument].present? || params[:direction_mode].present?
    end
  end
end
