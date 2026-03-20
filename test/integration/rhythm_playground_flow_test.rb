require "test_helper"

class RhythmPlaygroundFlowTest < ActionDispatch::IntegrationTest
  setup do
    @password = "password123"
    @user = User.create!(
      email: "rhythm.playground@example.com",
      password: @password,
      password_confirmation: @password,
      full_name: "Aluno Ritmica",
      plan: "Pulso"
    )
  end

  test "renders the rhythm playground for an authenticated user" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "ritmica")

    assert_response :success
    assert_includes response.body, "Playground de rítmica"
    assert_includes response.body, "Tipo de atividade"
    assert_includes response.body, "<svg"
  end

  test "stores rhythm state server-side and keeps only a token in session" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "ritmica", activity_mode: "syncopation")

    state_token = @request.session[:rhythm_playground_state_token]
    state_key = "playground:ritmica:#{@user.id}:#{state_token}"
    stored_state = StudentHubController::RHYTHM_PLAYGROUND_STATE_FALLBACK_STORE.read(state_key)
    stored_exercise = stored_state.fetch("exercise")

    assert state_token.present?
    assert_nil @request.session[:rhythm_exercise]
    assert_equal %w[a b m o], stored_exercise.keys.sort
    assert_equal 4, stored_exercise.fetch("o").size
  end

  test "correct answer generates a fresh rhythm round in the turbo frame" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "ritmica", activity_mode: "pulse")
    assert_response :success

    state_token = @request.session[:rhythm_playground_state_token]
    state_key = "playground:ritmica:#{@user.id}:#{state_token}"
    exercise = StudentHubController::RHYTHM_PLAYGROUND_STATE_FALLBACK_STORE.read(state_key).fetch("exercise")
    initial_signature = response.body[/data-rhythm-player-exercise-signature-value="([^"]+)"/, 1]

    post submit_app_playground_answer_path,
         params: {
           activity: "ritmica",
           selected_option_id: exercise.fetch("a"),
           exercise_signature: initial_signature,
           activity_mode: "pulse"
         },
         headers: { "Turbo-Frame" => "rhythm_playground" }

    assert_response :success
    refute_includes response.body, initial_signature
    assert_includes response.body, "data-rhythm-player-exercise-signature-value"
    assert_includes response.body, "Resposta correta"
  end
end
