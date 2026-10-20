require "test_helper"

class PlaygroundCompactLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "compact@example.test", password: "password123", full_name: "Layout", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "each playground keeps its instructions and four answers beside an accessible settings disclosure" do
    %w[leitura percepcao harmonia ritmica].each do |area|
      get app_playground_path(activity: area)
      assert_response :success
      assert_select "nav[aria-label='Áreas de prática'] a", count: 4
      assert_select "nav[aria-label='Áreas de prática'] a[aria-current='page']", count: 1
      assert_select "details.playground-settings:not([open]) summary", text: /Configurar treino/
      assert_select "details form.playground-controls", count: 1
      assert_select ".playground-trainer h2.exercise-question", count: 1
      assert_select ".playground-response-panel form button", count: 4
      assert_select ".playground-response-panel [name=assignment_id]", count: 4
      assert_select ".playground-response-panel [name=attempt_token]", count: 4
    end
  end

  test "a completed round is announced separately from the new question and keeps the next question available" do
    get app_playground_path(activity: "leitura")
    assignment = @user.exercise_assignments.last
    post submit_app_playground_answer_path, params: { activity: "leitura", assignment_id: assignment.public_id,
      attempt_token: assignment.answer_token, selected_option_id: assignment.exercise_payload.fetch("correct_option_id") },
      headers: { "Turbo-Frame" => "reading_playground" }
    assert_response :success
    assert_select ".playground-feedback", count: 0
    assert_select ".playground-previous-result[role=status][aria-live=polite]", text: /Rodada anterior concluída/
    assert_select "a[aria-label='Próxima pergunta']", count: 1
    assert_operator response.body.index('class="playground-previous-result"'), :<, response.body.index('class="playground-response-panel"')
  end
end
