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
    assert_select "h1", text: "Rítmica"
    assert_includes response.body, "Tipo de atividade"
    assert_includes response.body, "<svg"
  end

  test "stores rhythm state server-side and keeps only a token in session" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "ritmica", activity_mode: "subdivision")

    state_token = @request.session[:rhythm_playground_state_token]
    state_key = "playground:ritmica:#{@user.id}:#{state_token}"
    stored_state = StudentHubController::RHYTHM_PLAYGROUND_STATE_FALLBACK_STORE.read(state_key)
    stored_exercise = stored_state.fetch("exercise")

    assert state_token.present?
    assert_nil @request.session[:rhythm_exercise]
    assert_equal %w[a b m o], stored_exercise.keys.sort
    assert_equal 4, stored_exercise.fetch("o").size
  end

  test "syncopation cannot be selected or requested through an old link" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    get app_playground_path(activity: "ritmica")
    assert_response :success
    assert_select 'input[name="activity_mode"][value="syncopation"]', count: 0
    assert_no_difference ["ExerciseAssignment.count", "StudyActivity.count"] do
      get app_playground_path(activity: "ritmica", activity_mode: "syncopation")
      assert_redirected_to app_pratica_path
      assert_includes flash[:alert], "nenhuma resposta foi contabilizada"
    end
  end

  test "correct answer generates a fresh rhythm round in the turbo frame" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "ritmica", activity_mode: "pulse")
    assert_response :success

    state_token = @request.session[:rhythm_playground_state_token]
    state_key = "playground:ritmica:#{@user.id}:#{state_token}"
    exercise = StudentHubController::RHYTHM_PLAYGROUND_STATE_FALLBACK_STORE.read(state_key).fetch("exercise")
    submitted_assignment = @user.exercise_assignments.order(:id).last
    initial_signature = response.body[/data-rhythm-player-exercise-signature-value="([^"]+)"/, 1]

    post submit_app_playground_answer_path,
         params: {
           activity: "ritmica",
           selected_option_id: exercise.fetch("a"),
           assignment_id: submitted_assignment.public_id,
           attempt_token: submitted_assignment.answer_token,
           playback_status: "ready",
           activity_mode: "pulse"
         },
         headers: { "Turbo-Frame" => "rhythm_playground" }

    assert_response :success
    refute_includes response.body, initial_signature
    assert_includes response.body, "data-rhythm-player-exercise-signature-value"
    assert_includes response.body, "Resposta correta"
  end
end
