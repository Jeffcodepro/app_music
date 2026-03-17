class StudentHubController < ApplicationController
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

  def playground; end

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
end
