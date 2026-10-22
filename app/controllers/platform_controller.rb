class PlatformController < ApplicationController
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

  before_action :authenticate_user!
  layout "platform"

  def dashboard
    @study_calendar = StudyCalendar.new(current_user, month: params[:month], access_available: !@daily_visit_unavailable)
  end

  def nivelamento; end

  def trilhas
    @study_track_themes = STUDY_TRACK_THEMES
  end

  def trilha_tema
    @study_track_theme = find_study_track_theme(params[:tema])
    return if @study_track_theme.present?

    redirect_to app_trilhas_path, alert: "Tema da trilha não encontrado."
  end

  def aulas; end

  def pratica; end

  def carreira; end

  def arena; end

  def perfil; end

  def dados_pessoais; end
  def assinaturas; end
  def notificacoes; end
  def aparencia; end

  def update_perfil
    if current_user.update(perfil_params)
      redirect_to app_account_personal_path, notice: "Sua conta foi atualizada com sucesso."
    else
      flash.now[:alert] = "Não foi possível salvar as alterações."
      render :dados_pessoais, status: :unprocessable_entity
    end
  end

  def update_plan
    selected_plan = params[:plan].to_s
    allowed_plans = ["Primeira Nota", "Pulso", "Harmonia", "Maestro"]

    unless allowed_plans.include?(selected_plan)
      redirect_to app_account_subscription_path, alert: "Selecione um plano válido."
      return
    end

    if current_user.update(plan: selected_plan)
      redirect_to app_account_subscription_path, notice: "Plano atualizado com sucesso."
    else
      redirect_to app_account_subscription_path, alert: "Não foi possível atualizar o plano."
    end
  end

  private

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
