require "test_helper"

class StudyEditorialTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "editorial@example.test", password: "password123", full_name: "Estudante", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "current milestone is restricted to dashboard practice history and perception" do
    [app_dashboard_path, app_pratica_path, app_practice_result_path, app_playground_path(activity: "percepcao")].each do |path|
      get path
      assert_response :success
      assert_select "body.study-editorial", count: 1
    end
    [app_perfil_path, app_trilhas_path, onboarding_plan_path,
      edit_user_registration_path, *%w[leitura ritmica harmonia].map { |area| app_playground_path(activity: area) }].each do |path|
      get path
      assert_response :success
      assert_select "body.study-editorial, .perception-editorial, .dashboard-editorial", count: 0
    end
    delete destroy_user_session_path
    [root_path, new_user_session_path, new_user_registration_path, new_user_password_path].each do |path|
      get path
      assert_response :success
      assert_select "body.study-editorial", count: 0
    end
  end

  test "empty dashboard provides four real destinations and a working practice action" do
    get app_dashboard_path
    assert_select ".study-index__list li", count: 4
    %w[leitura percepcao ritmica harmonia].each do |area|
      assert_select ".study-index__entry[href='#{app_playground_path(activity: area)}']", count: 1
    end
    assert_select "[data-testid=empty-history] a[href='#{app_pratica_path}']", count: 1
    assert_select "[data-testid=attempt-count]", text: "0"
    assert_select "[data-testid=xp-total]", text: "0"
  end

  test "perception preserves four opaque answer identities and does not render the answer key" do
    get app_playground_path(activity: "percepcao")
    assignment = @user.exercise_assignments.last
    assert_select "turbo-frame#perception_playground", count: 1
    assert_select ".perception-editorial[data-controller='interval-player preferences']", count: 1
    assert_select ".perception-editorial[data-interval-player-exercise-signature-value='#{assignment.public_id}']", count: 1
    assert_select "form[action='#{submit_app_playground_answer_path}']", count: 4
    %w[assignment_id attempt_token selected_option_id playback_status].each { |name| assert_select ".perception-options input[name=#{name}]", count: 4 }
    assert_select ".perception-options button[data-action='click->interval-player#guardAnswer']", count: 4
    assert_select "[data-correct], [data-correct-option-id], [name=correct_option_id], [name=xp_earned]", count: 0
    assert_select "[aria-label='Resultados desta sessão']", count: 1
    assert_select ".is-last-answer", count: 0
  end

  test "last answer is marked from server feedback and credit remains capped after a retry" do
    get app_playground_path(activity: "percepcao")
    assignment = @user.exercise_assignments.last
    correct_id = assignment.exercise_payload.fetch("correct_option_id")
    wrong_id = assignment.exercise_payload.fetch("options").find { |option| option.fetch("id") != correct_id }.fetch("id")
    answer(assignment, wrong_id)
    assert_response :success
    assert_select ".playground-feedback.is-incorrect[role=status][aria-live=polite]", count: 1
    assert_select ".perception-option.is-last-answer:not([disabled]) .perception-option__meta", text: "Sua resposta"
    assert_equal 6, @user.study_activities.sum(:xp_earned)
    answer(assignment.reload, correct_id)
    assert_response :success
    assert_select ".perception-option.is-last-answer[disabled] .perception-option__meta", text: "Sua resposta"
    assert_select ".perception-options button[disabled]", count: 4
    assert_select ".playground-feedback.is-correct", count: 1
    assert_equal 20, @user.study_activities.sum(:xp_earned)
    get app_dashboard_path
    assert_select "[data-testid=attempt-count]", text: "2"
    assert_select "[data-testid=xp-total]", text: "20"
    assert_select "[data-testid=history-row]", count: 2
    assert_select ".study-journal__list time[datetime]", count: 2
  end

  private

  def answer(assignment, option_id)
    post submit_app_playground_answer_path, params: {
      activity: "percepcao", assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
      selected_option_id: option_id, playback_status: "ready"
    }, headers: { "Turbo-Frame" => "perception_playground" }
  end
end
