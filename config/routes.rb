Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  root to: "pages#home"

  authenticate :user do
    get "app", to: redirect("/app/dashboard")
    get "app/dashboard", to: "platform#dashboard", as: :app_dashboard
    get "app/nivelamento", to: "platform#nivelamento", as: :app_nivelamento
    get "app/trilhas", to: "platform#trilhas", as: :app_trilhas
    get "app/trilhas/tema/:tema", to: "platform#trilha_tema", as: :app_trilha_tema
    get "app/aulas", to: "platform#aulas", as: :app_aulas
    get "app/pratica", to: "platform#pratica", as: :app_pratica
    get "app/carreira", to: "platform#carreira", as: :app_carreira
    get "app/arena", to: "platform#arena", as: :app_arena
    get "app/perfil", to: "platform#perfil", as: :app_perfil
    patch "app/perfil", to: "platform#update_perfil", as: :update_app_perfil
    patch "app/perfil/plan", to: "platform#update_plan", as: :update_app_plan

    # Estruturas adicionais do aluno (README)
    get "app/trilhas/:area/:nivel", to: "student_hub#trail_show", as: :app_trail
    get "app/aulas/:id", to: "student_hub#lesson_show", as: :app_lesson
    get "app/pratica/resultado", to: "student_hub#practice_result", as: :app_practice_result
    get "app/playground", to: "student_hub#playground", as: :app_playground
    get "app/desafios", to: "student_hub#challenges", as: :app_challenges
    get "app/ranking", to: "student_hub#ranking", as: :app_ranking
    get "app/conquistas", to: "student_hub#achievements", as: :app_achievements
    get "app/bolsa-evolucao", to: "student_hub#scholarship", as: :app_scholarship
    get "app/assinatura/comparacao", to: "student_hub#plans_compare", as: :app_plans_compare
    get "app/assinatura/historico", to: "student_hub#billing_history", as: :app_billing_history
  end

  get "onboarding/welcome", to: "onboarding#welcome", as: :onboarding_welcome
  get "onboarding/objective", to: "onboarding#objective", as: :onboarding_objective
  patch "onboarding/objective", to: "onboarding#update_objective", as: :update_onboarding_objective
  get "onboarding/profile", to: "onboarding#profile", as: :onboarding_profile
  patch "onboarding/profile", to: "onboarding#update_profile", as: :update_onboarding_profile
  get "onboarding/result", to: "onboarding#result", as: :onboarding_result

  get "onboarding/plan", to: "onboarding#plan", as: :onboarding_plan
  patch "onboarding/plan", to: "onboarding#update_plan", as: :update_onboarding_plan
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
