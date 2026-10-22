require "test_helper"

class PerceptionPlaygroundFlowTest < ActionDispatch::IntegrationTest
  setup do
    @password = "password123"
    @user = User.create!(
      email: "playground@example.com",
      password: @password,
      password_confirmation: @password,
      full_name: "Aluno Playground",
      plan: "Pulso"
    )
  end

  test "renders the perception playground for an authenticated user" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "percepcao")

    assert_response :success
    assert_select "h1", text: "Percepção"
    assert_includes response.body, "Qual intervalo você ouviu?"
    assert_includes response.body, "Tocar intervalo"
  end
  test "feedback uses musical direction terms without changing legacy exercise payloads" do
    controller = StudentHubController.new
    %w[ascending descending].zip(%w[Ascendente Descendente]).each do |direction, label|
      exercise = { direction: direction, direction_label: direction == "descending" ? "Decrescente" : "Crescente", reference_pitch: "D5", target_pitch: "C5" }
      feedback = controller.send(:build_perception_playground_feedback, exercise: exercise, selected_option: { label: "Segunda maior (M2)" }, correct: true)
      assert_equal label, feedback[:direction_label]
      assert_equal direction == "descending" ? "Decrescente" : "Crescente", exercise[:direction_label]
    end
  end

end
