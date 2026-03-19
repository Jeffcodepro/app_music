require "test_helper"

class HarmonyPlaygroundFlowTest < ActionDispatch::IntegrationTest
  setup do
    @password = "password123"
    @user = User.create!(
      email: "harmony.playground@example.com",
      password: @password,
      password_confirmation: @password,
      full_name: "Aluno Harmonia",
      plan: "Pulso"
    )
  end

  test "renders the harmony playground for an authenticated user" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "harmonia")

    assert_response :success
    assert_includes response.body, "Playground de harmonia"
    assert_includes response.body, "Ouvir blocado"
    assert_includes response.body, "Ouvir nota por nota"
  end

  test "stores a compact harmony exercise server-side and keeps only a token in session" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "harmonia", question_mode: "progression", chord_structure: "tetrad")

    state_token = @request.session[:harmony_playground_state_token]
    state_key = "playground:harmonia:#{@user.id}:#{state_token}"
    stored_state = StudentHubController::HARMONY_PLAYGROUND_STATE_FALLBACK_STORE.read(state_key)
    stored_exercise = stored_state.fetch("exercise")

    assert state_token.present?
    assert_nil @request.session[:harmony_exercise]
    assert_equal %w[a d i k m o p s t], stored_exercise.keys.sort
    assert_equal 4, stored_exercise.fetch("o").size
    refute_includes stored_exercise.keys, "audio_sequence"
    refute_includes stored_exercise.keys, "context_items"
  end

  test "correct answer generates a fresh harmony round in the turbo frame" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "harmonia", question_mode: "quality", chord_structure: "triad")
    assert_response :success

    state_token = @request.session[:harmony_playground_state_token]
    state_key = "playground:harmonia:#{@user.id}:#{state_token}"
    exercise = StudentHubController::HARMONY_PLAYGROUND_STATE_FALLBACK_STORE.read(state_key).fetch("exercise")
    initial_signature = response.body[/data-harmony-player-exercise-signature-value="([^"]+)"/, 1]

    post submit_app_playground_answer_path,
         params: {
           activity: "harmonia",
           selected_option_id: exercise.fetch("a"),
           exercise_signature: initial_signature,
           question_mode: "quality",
           chord_structure: "triad",
           instrument: "piano"
         },
         headers: { "Turbo-Frame" => "harmony_playground" }

    assert_response :success
    refute_includes response.body, initial_signature
    assert_includes response.body, "data-harmony-player-exercise-signature-value"
    assert_includes response.body, "Resposta correta"
  end

  test "melodic instruments hide blocked playback" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "harmonia", instrument: "flute")

    assert_response :success
    refute_includes response.body, "Ouvir blocado"
    assert_includes response.body, "reproduz o material nota por nota"
  end
end
