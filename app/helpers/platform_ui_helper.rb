module PlatformUiHelper
  NAVIGATION = [
    { label: "Dashboard", route: :app_dashboard_path, icon: "home", section: "home" },
    { label: "Prática", route: :app_pratica_path, icon: "music", section: "practice" },
    { label: "Trilhas de estudo", route: :app_trilhas_path, icon: "route", section: "trails" },
    { label: "Histórico", route: :app_practice_result_path, icon: "book", section: "history" },
    { label: "Minha conta", route: :app_perfil_path, icon: "user", section: "account" },
    { label: "Aulas", route: :app_aulas_path, icon: "book", section: "lessons", preparing: true },
    { label: "Modo carreira", route: :app_carreira_path, icon: "award", section: "career", preparing: true },
    { label: "Arena Musical", route: :app_arena_path, icon: "radio", section: "arena" }
  ].map(&:freeze).freeze

  def platform_navigation
    NAVIGATION
  end

  def feedback_for_round?(feedback, exercise, area:)
    feedback.present? && feedback[:activity] == area &&
      feedback[:assignment_id].present? && exercise[:assignment_id].present? &&
      feedback[:assignment_id] == exercise[:assignment_id]
  end

  def completed_previous_round?(feedback, exercise, area:)
    feedback.present? && feedback[:activity] == area && feedback[:correct] == true &&
      feedback[:assignment_id].present? && exercise[:assignment_id].present? &&
      feedback[:assignment_id] != exercise[:assignment_id]
  end

  # Current approval milestone. Other student screens keep their presentation.
  def editorial_study_screen?
    (controller_name == "platform" && %w[dashboard pratica].include?(action_name)) ||
      (controller_name == "student_hub" && action_name == "practice_result") ||
      (controller_name == "student_hub" && action_name == "playground" && @selected_activity&.dig(:slug) == "percepcao")
  end

  def platform_section
    return "account" if devise_controller? && controller_name == "registrations"
    path = request.path
    return "trails" if path.start_with?("/app/trilhas")
    return "lessons" if path.start_with?("/app/aulas")
    return "history" if path == "/app/pratica/resultado"
    return "practice" if path.start_with?("/app/pratica", "/app/playground")
    return "arena" if path == "/app/arena" || path.start_with?("/app/arena/")
    return "career" if path.match?(%r{\A/app/(carreira|desafios|ranking|conquistas|bolsa-evolucao)})
    return "account" if path.start_with?("/app/perfil", "/app/assinatura", "/onboarding", "/users/edit")
    "home"
  end

  def platform_section_label
    platform_navigation.find { |item| item[:section] == platform_section }.fetch(:label)
  end

  def account_navigation
    [["Visão geral", app_perfil_path, "home"], ["Assinaturas e compras", app_account_subscription_path, "monitor"],
      ["Dados de acesso", edit_user_registration_path, "key"], ["Dados pessoais", app_account_personal_path, "user"],
      ["Notificações", app_account_notifications_path, "bell"], ["Aparência", app_account_appearance_path, "sun"]]
  end

  def account_page_active?(path)
    path == request.path || (path == edit_user_registration_path && devise_controller? && controller_name == "registrations") ||
      (path == app_account_personal_path && action_name == "update_perfil")
  end

  def platform_attempts(user)
    ExerciseAttempt.joins(:exercise_assignment).where(exercise_assignments: { user_id: user.id })
  end

  def platform_area_label(area)
    { "leitura" => "Leitura", "ritmica" => "Rítmica", "percepcao" => "Percepção", "harmonia" => "Harmonia" }.fetch(area, "Prática")
  end

  # Links use presentation preferences only, never correction/credit metadata.
  def platform_assignment_practice_path(assignment)
    preferences = assignment.exercise_payload.slice("question_mode", "instrument", "direction_mode", "activity_mode", "chord_structure", "clef_mode", "season_mode", "level", "meter_id")
    preferences["activity_mode"] = assignment.exercise_payload["requested_activity_mode"] if assignment.exercise_payload["requested_activity_mode"].present?
    preferences["meter_id"] = assignment.exercise_payload["requested_meter_id"] if assignment.exercise_payload["requested_meter_id"].present?
    app_playground_path(activity: assignment.area, **preferences.symbolize_keys)
  end

  def public_navigation
    [{ label: "Vantagens", href: "#vantagens" }, { label: "Conteúdo", href: "#conteudo" },
     { label: "Planos", href: "#planos" }, { label: "Dúvidas", href: "#faq" }]
  end

  # Repo-native icons avoid a runtime CDN and global DOM replacement listeners.
  def ui_icon(name)
    paths = {
      "play" => '<path d="m8 4 12 8-12 8Z"/>',
      "home" => '<path d="m3 10 9-7 9 7v10H15v-7H9v7H3Z"/>',
      "route" => '<circle cx="6" cy="5" r="2"/><circle cx="18" cy="19" r="2"/><path d="M8 5h8a4 4 0 0 1 0 8H8a3 3 0 0 0 0 6h8"/>',
      "book" => '<path d="M12 5v16M12 5C8 2 3 3 3 3v15s5-1 9 3c4-4 9-3 9-3V3s-5-1-9 2Z"/>',
      "music" => '<path d="M9 18V5l12-2v13M9 8l12-2"/><ellipse cx="6" cy="18" rx="3" ry="3"/><ellipse cx="18" cy="16" rx="3" ry="3"/>',
      "award" => '<circle cx="12" cy="8" r="5"/><path d="m8 12-2 9 6-3 6 3-2-9"/>',
      "radio" => '<circle cx="12" cy="12" r="2"/><path d="M7 7a7 7 0 0 0 0 10M17 7a7 7 0 0 1 0 10M4 4a11 11 0 0 0 0 16M20 4a11 11 0 0 1 0 16"/>',
      "user" => '<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
      "menu" => '<path d="M4 6h16M4 12h16M4 18h16"/>',
      "sidebar" => '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18m7-13-4 4 4 4"/>',
      "key" => '<circle cx="8" cy="8" r="5"/><path d="m12 12 9 9m-4-4 3-3m-6 0 3-3"/>',
      "settings" => '<path d="m10 3 4 0 1 3 3 1 3 1-1 4 1 4-3 1-3 1-1 3h-4l-1-3-3-1-3-1 1-4-1-4 3-1 3-1Z"/><circle cx="12" cy="12" r="3"/>',
      "logout" => '<path d="M10 3H4v18h6m5-14 5 5-5 5m-7-5h12"/>',
      "bell" => '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
      "close" => '<path d="m6 6 12 12M6 18 18 6"/>',
      "arrow" => '<path d="M4 12h16m-6-6 6 6-6 6"/>',
      "headphones" => '<path d="M3 14v-2a9 9 0 0 1 18 0v2"/><rect x="3" y="12" width="4" height="8" rx="2"/><rect x="17" y="12" width="4" height="8" rx="2"/>',
      "drum" => '<ellipse cx="12" cy="8" rx="9" ry="4"/><path d="M3 8v10c0 5 18 5 18 0V8M7 12l2 9M17 12l-2 9M6 2l7 5M18 2l-5 5"/>',
      "sun" => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1 1m12 12 1 1M5 19l1-1M18 6l1-1"/>',
      "moon" => '<path d="M20 15a8.5 8.5 0 0 1-11-11 8.5 8.5 0 1 0 11 11Z"/>',
      "monitor" => '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/>'
    }
    content_tag(:svg, paths.fetch(name, paths.fetch("music")).html_safe,
      viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": "1.7",
      "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true", class: "ui-icon")
  end
end
