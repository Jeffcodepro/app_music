class PlatformController < ApplicationController
  GUIDED_TOPICS = [
    {
      slug: "leitura",
      title: "Estruturação / Leitura",
      description: "Leitura de pauta, claves e organização visual da música."
    },
    {
      slug: "ritmica",
      title: "Rítmica",
      description: "Pulso, subdivisão e controle de tempo para execução com precisão."
    },
    {
      slug: "percepcao",
      title: "Percepção",
      description: "Escuta ativa, identificação de intervalos e reconhecimento de padrões."
    },
    {
      slug: "harmonia",
      title: "Harmonia",
      description: "Escalas, graus e construção de acordes em progressão musical."
    }
  ].freeze

  AREA_LABELS = {
    "leitura" => "Estruturação / Leitura",
    "ritmica" => "Rítmica",
    "percepcao" => "Percepção",
    "harmonia" => "Harmonia",
    "apreciacao" => "Apreciação",
    "historia" => "História da Música"
  }.freeze

  STUDY_TRACK_THEMES = [
    {
      slug: "leitura",
      title: "Estruturação / Leitura",
      icon: "book-open",
      short_description: "Leitura de pauta, claves e interpretação da escrita musical com fluidez progressiva.",
      overview: "Essa trilha organiza a leitura musical desde os símbolos básicos até a interpretação estrutural em contextos mais avançados.",
      levels: [
        {
          name: "Nível 1",
          topics: [
            "pauta musical",
            "claves",
            "símbolos básicos",
            "organização visual da música",
            "leitura inicial"
          ]
        },
        {
          name: "Nível 2",
          topics: [
            "consolidação da leitura",
            "figuras em contexto",
            "relação entre leitura e compasso",
            "leitura mais fluida"
          ]
        },
        {
          name: "Nível 3",
          topics: [
            "leitura com mais complexidade rítmica",
            "leitura associada à percepção e forma"
          ]
        },
        {
          name: "Nível 4",
          topics: [
            "leitura aplicada a contextos mais avançados",
            "interpretação estrutural da escrita musical"
          ]
        }
      ]
    },
    {
      slug: "ritmica",
      title: "Rítmica",
      icon: "activity",
      short_description: "Pulso, subdivisão e precisão de tempo com evolução até estruturas rítmicas complexas.",
      overview: "A trilha de Rítmica desenvolve controle de tempo, leitura de figuras e combinação de camadas rítmicas para execução consistente.",
      levels: [
        {
          name: "Nível 1",
          topics: [
            "semibreves",
            "mínimas",
            "semínimas",
            "colcheias",
            "pulsação",
            "organização rítmica simples"
          ]
        },
        {
          name: "Nível 2",
          topics: [
            "semicolcheias",
            "compassos compostos",
            "subdivisão intermediária"
          ]
        },
        {
          name: "Nível 3",
          topics: [
            "mais de uma voz",
            "polirritmia",
            "ritmos tradicionais do Brasil",
            "ritmos de outros países",
            "ritmos mais complexos"
          ]
        },
        {
          name: "Nível 4",
          topics: [
            "estruturas rítmicas mais sofisticadas",
            "combinação de camadas rítmicas"
          ]
        }
      ]
    },
    {
      slug: "percepcao",
      title: "Percepção",
      icon: "headphones",
      short_description: "Escuta ativa, comparação auditiva e reconhecimento de intervalos em uma ou mais vozes.",
      overview: "Essa trilha fortalece a audição musical para identificar padrões melódicos e intervalares com precisão crescente.",
      levels: [
        {
          name: "Nível 1",
          topics: [
            "solfejos simples",
            "uníssono",
            "segundas",
            "terças",
            "oitavas"
          ]
        },
        {
          name: "Nível 2",
          topics: [
            "solfejos intermediários",
            "quartas",
            "quintas",
            "comparação auditiva"
          ]
        },
        {
          name: "Nível 3",
          topics: [
            "percepção em duas vozes",
            "sextas",
            "sétimas"
          ]
        },
        {
          name: "Nível 4",
          topics: [
            "duas ou mais vozes",
            "intervalos compostos",
            "reconhecimento contextual e comparativo"
          ]
        }
      ]
    },
    {
      slug: "harmonia",
      title: "Harmonia",
      icon: "music",
      short_description: "Escalas, graus, acordes, progressões e funções harmônicas para entendimento tonal completo.",
      overview: "A trilha de Harmonia apresenta as bases tonais e avança para relações tensionais e cadenciais em contextos musicais reais.",
      levels: [
        {
          name: "Nível 1",
          topics: [
            "fundamentos de escalas",
            "graus",
            "organização tonal inicial"
          ]
        },
        {
          name: "Nível 2",
          topics: [
            "introdução à harmonia",
            "formação de acordes",
            "tríades",
            "relações básicas entre acordes"
          ]
        },
        {
          name: "Nível 3",
          topics: [
            "progressões",
            "campo harmônico",
            "ampliação da construção harmônica"
          ]
        },
        {
          name: "Nível 4",
          topics: [
            "funções harmônicas",
            "acordes com dissonância",
            "cadências",
            "relações tensionais"
          ]
        }
      ]
    },
    {
      slug: "apreciacao",
      title: "Apreciação",
      icon: "film",
      short_description: "Escuta contextual de obras e formas musicais para ampliar repertório, linguagem e referência estética.",
      overview: "A trilha de Apreciação conecta audição, repertório e forma musical, aproximando teoria e prática por meio de exemplos conhecidos.",
      levels: [
        {
          name: "Nível 1",
          topics: [
            "músicas conhecidas",
            "trilhas de filmes",
            "musicais",
            "curiosidades",
            "conexão com as demais áreas"
          ]
        },
        {
          name: "Nível 2",
          topics: [
            "identificação de instrumentos",
            "comparação de timbres",
            "famílias instrumentais"
          ]
        },
        {
          name: "Nível 3",
          topics: [
            "formas convencionais",
            "ABA",
            "ABACA",
            "repetição, contraste e retorno"
          ]
        },
        {
          name: "Nível 4",
          topics: [
            "formas clássicas",
            "sonata",
            "concerto",
            "tema e variações"
          ]
        }
      ]
    },
    {
      slug: "historia",
      title: "História da Música",
      icon: "landmark",
      short_description: "Panorama histórico dos períodos musicais para entender estilos, linguagem e contexto cultural.",
      overview: "Essa trilha apresenta os principais períodos da história da música e como cada fase influencia repertório, forma e estética.",
      levels: [
        {
          name: "Nível 3",
          topics: [
            "Medieval",
            "Renascentista",
            "Barroco"
          ]
        },
        {
          name: "Nível 4",
          topics: [
            "Clássico",
            "Romântico",
            "Século XX"
          ]
        }
      ]
    }
  ].freeze

  INTERNAL_STAGES = [
    {
      name: "Fundamentos",
      lessons: [
        { slug: "fundamentos-1", title: "Conceitos-base", objective: "Base visual e auditiva inicial." },
        { slug: "fundamentos-2", title: "Leitura inicial", objective: "Primeira fluidez de leitura e pulso." }
      ]
    },
    {
      name: "Consolidação",
      lessons: [
        { slug: "consolidacao-1", title: "Conexão de elementos", objective: "Unir leitura, ritmo e escuta." },
        { slug: "consolidacao-2", title: "Aplicação guiada", objective: "Fixar padrões em contexto musical." }
      ]
    },
    {
      name: "Aplicação",
      lessons: [
        { slug: "aplicacao-1", title: "Integração entre áreas", objective: "Usar conceitos em combinação." },
        { slug: "aplicacao-2", title: "Checkpoint preparatório", objective: "Ajustes antes da avaliação." }
      ]
    },
    {
      name: "Domínio",
      lessons: [
        { slug: "dominio-1", title: "Situações avançadas", objective: "Resolver contextos mais complexos." },
        { slug: "dominio-2", title: "Síntese final", objective: "Consolidar entendimento global." }
      ]
    }
  ].freeze

  before_action :authenticate_user!
  layout "platform"

  def dashboard; end

  def nivelamento; end

  def trilhas
    @study_track_themes = STUDY_TRACK_THEMES
  end

  def trilha_tema
    @study_track_theme = find_study_track_theme(params[:tema])
    return if @study_track_theme.present?

    redirect_to app_trilhas_path, alert: "Tema da trilha não encontrado."
  end

  def aulas
    @selected_mode = select_mode
    @guided_topics = GUIDED_TOPICS
    @selected_area = select_area
    @selected_area_label = AREA_LABELS[@selected_area]
    @stage_index = internal_stage_index(current_user, @selected_area)
    @current_stage = INTERNAL_STAGES[@stage_index]
    @recommended_lesson = @current_stage[:lessons].first
  end

  def pratica; end

  def carreira; end

  def arena; end

  def perfil; end

  def update_perfil
    if current_user.update(perfil_params)
      redirect_to app_perfil_path, notice: "Sua conta foi atualizada com sucesso."
    else
      flash.now[:alert] = "Não foi possível salvar as alterações."
      render :perfil, status: :unprocessable_entity
    end
  end

  def update_plan
    selected_plan = params[:plan].to_s
    allowed_plans = ["Primeira Nota", "Pulso", "Harmonia", "Maestro"]

    unless allowed_plans.include?(selected_plan)
      redirect_to app_perfil_path(anchor: "assinatura"), alert: "Selecione um plano válido."
      return
    end

    if current_user.update(plan: selected_plan)
      redirect_to app_perfil_path(anchor: "assinatura"), notice: "Plano atualizado com sucesso."
    else
      redirect_to app_perfil_path(anchor: "assinatura"), alert: "Não foi possível atualizar o plano."
    end
  end

  private

  def select_mode
    requested_mode = params[:mode].to_s
    return requested_mode if %w[guiado livre].include?(requested_mode)

    nil
  end

  def select_area
    requested = params[:area].to_s
    return requested if AREA_LABELS.key?(requested)

    area_counts = current_user.study_activities.group(:area).count
    most_practiced = area_counts.max_by { |_area, count| count }&.first
    AREA_LABELS.key?(most_practiced) ? most_practiced : "leitura"
  end

  def internal_stage_index(user, area)
    activity_count = user.study_activities.where(area: area).count

    case activity_count
    when 0..5 then 0
    when 6..14 then 1
    when 15..29 then 2
    else 3
    end
  end

  def perfil_params
    params.require(:user).permit(
      :avatar,
      :full_name,
      :phone,
      :primary_instrument,
      :study_goal,
      :weekly_study_minutes,
      :learning_mode
    )
  end

  def find_study_track_theme(theme_slug)
    STUDY_TRACK_THEMES.find { |theme| theme[:slug] == theme_slug.to_s }
  end
end
