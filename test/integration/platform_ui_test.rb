require "test_helper"

class PlatformUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "platform-ui@example.test", password: "password123", full_name: "Estudante", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "new student sees an honest dashboard without invented lessons or notifications" do
    get app_dashboard_path
    assert_response :success
    assert_select "[data-testid=empty-history]", count: 1
    assert_select "[data-testid=attempt-count]", text: "0"
    assert_select "[data-testid=xp-total]", text: "0"
    assert_select ".study-area", count: 4
    assert_select "input[type=search], .app-badge", count: 0
    refute_match(/Aulas assistidas|Minutos praticados|Retomar a aula/, response.body)
  end

  test "dashboard and history show only persisted attempts belonging to the signed in student" do
    submit_reading(@user)
    other = User.create!(email: "other-platform@example.test", password: "password123", full_name: "Outro", plan: "Pulso")
    2.times { submit_reading(other) }
    get app_dashboard_path
    assert_select "[data-testid=attempt-count]", text: "1"
    assert_select "[data-testid=xp-total]", text: "20"
    assert_select "[data-testid=history-row]", count: 1
    get app_practice_result_path
    assert_select "[data-testid=history-row]", count: 1
    assert_select "[data-testid=correct-count]", text: "1"
  end

  test "old lesson links never advertise fictitious episodes or a fake player" do
    [app_aulas_path, app_aulas_path(mode: "guiado"), app_lesson_path("guia-leitura"), app_lesson_path("A99", mode: "livre")].each do |path|
      get path
      assert_response :success
      assert_select "[data-testid=lessons-preparing]", count: 1
      assert_select "video, .lesson-fake-player, .lesson-chip, .lesson-video-card", count: 0
      refute_match(/Episódios|Temporada ativa|Iniciar aula|0\.75x/, response.body)
    end
  end

  test "all existing platform routes use shared accessible navigation and have no inert buttons" do
    paths = [app_dashboard_path, app_trilhas_path, app_trilha_tema_path("leitura"), app_trail_path("leitura", "1"),
      app_aulas_path, app_pratica_path, app_practice_result_path, app_carreira_path, app_arena_path, app_perfil_path,
      app_nivelamento_path, app_challenges_path, app_ranking_path, app_achievements_path, app_scholarship_path,
      app_plans_compare_path, app_billing_history_path, onboarding_welcome_path, onboarding_objective_path,
      onboarding_profile_path, onboarding_result_path, onboarding_plan_path]
    paths.each do |path|
      get path
      assert_response :success, path
      assert_select "html[lang=pt-BR]", count: 1
      assert_select "a[href='#main-content']", count: 1
      assert_select "button[aria-controls=platform-sidebar][aria-expanded=false]", minimum: 1
      assert_select "nav[aria-label='Navegação principal']", count: 1
      assert_select "[data-controller~=theme]", count: 1
      assert_select "button[type=button]:not([data-action])", count: 0
      assert_select "h1", count: 1
      refute_match(/gateway de pagamento|R\$\s*34|Status: ativo/, response.body)
    end
  end

  test "account labels and updates retain real fields and credentials are protected" do
    get app_account_personal_path
    %w[full_name phone primary_instrument study_goal avatar].each do |field|
      assert_select "label[for=user_#{field}]", count: 1
    end
    patch update_app_perfil_path, params: { user: { full_name: "Novo nome", plan: "Maestro", email: "forged@example.test" } }
    assert_redirected_to app_account_personal_path
    assert_equal "Novo nome", @user.reload.full_name
    assert_equal "Pulso", @user.plan
    assert_equal "platform-ui@example.test", @user.email
    delete destroy_user_session_path
    get app_dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "onboarding review does not invent a placement result and plan entry preserves validation" do
    get onboarding_result_path
    refute_match(/Trilha recomendada|Primeiro módulo sugerido|5 vezes por semana/, response.body)
    patch update_onboarding_plan_path, params: { plan: "invalid" }
    assert_redirected_to onboarding_plan_path
    assert_equal "Pulso", @user.reload.plan
    patch update_onboarding_plan_path, params: { plan: "Primeira Nota" }
    assert_redirected_to app_dashboard_path
    assert_equal "Primeira Nota", @user.reload.plan
  end

  test "anonymous authentication pages share theme and label every real input" do
    delete destroy_user_session_path
    [new_user_session_path, new_user_registration_path, new_user_password_path].each do |path|
      get path
      assert_response :success
      assert_select "body.platform-ui[data-controller=theme]", count: 1
      assert_select "select[aria-label='Tema da interface']", count: 1
      assert_select "h1", count: 1
      assert_select "script[src*='tailwind'], script[src*='lucide']", count: 0
      css_select("input[type=email]").each do |field|
        assert_select "label[for='#{field['id']}']", count: 1
      end
    end
  end

  test "plan selection remains required and unknown themes redirect safely" do
    @user.update!(plan: nil)
    get app_dashboard_path
    assert_redirected_to onboarding_plan_path
    get onboarding_plan_path
    assert_response :success
    assert_select "form[action='#{update_onboarding_plan_path}']", count: 1
    @user.update!(plan: "Pulso")
    get app_trilha_tema_path("unknown")
    assert_redirected_to app_trilhas_path
  end

  private

  def submit_reading(user)
    exercise = ReadingNoteExerciseGenerator.new.call
    assignment = ExerciseAssignment.issue!(user:, area: "leitura", exercise:)
    ExerciseSubmission.call(user:, area: "leitura", assignment_id: assignment.public_id,
      attempt_token: assignment.answer_token, selected_option_id: exercise.fetch(:correct_option_id))
  end
end
