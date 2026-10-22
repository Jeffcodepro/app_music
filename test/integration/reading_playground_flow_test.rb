require "test_helper"

class ReadingPlaygroundFlowTest < ActionDispatch::IntegrationTest
  setup do
    @password = "password123"
    @user = User.create!(
      email: "reading.playground@example.com",
      password: @password,
      password_confirmation: @password,
      full_name: "Aluno Leitura",
      plan: "Pulso"
    )
  end

  def reading_state
    token = @request.session[:reading_playground_state_token] || @request.session["reading_playground_state_token"]
    key = "playground:leitura:#{@user.id}:#{token}"
    Rails.cache.read(key) || StudentHubController::READING_PLAYGROUND_STATE_FALLBACK_STORE.read(key)
  end

  test "renders the reading playground for an authenticated user" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura")

    assert_response :success
    assert_select "h1", text: "Leitura"
    assert_includes response.body, "Faixa de conteúdo"
    assert_includes response.body, "Nível 1"
    assert_includes response.body, "Tipo de pergunta"
    assert_includes response.body, "<svg"
  end

  test "stores a compact reading exercise in cache-backed reading state" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura", clef_mode: "alto", question_mode: "note_name", season_mode: "level_1")

    stored_exercise = reading_state.fetch("exercise")

    assert_equal %w[a c i l m o p q t v], stored_exercise.keys.sort
    assert_equal 4, stored_exercise.fetch("o").size
    assert_equal "level_1", stored_exercise.fetch("l")
    assert_nil @request.session[:reading_note_exercise]
    refute_includes stored_exercise.keys, "options"
    refute_includes stored_exercise.keys, "pitch_label"
  end

  test "correct answer generates a fresh reading round in the turbo frame" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura", clef_mode: "alto", question_mode: "note_name", season_mode: "level_2")
    assert_response :success

    exercise = reading_state.fetch("exercise")
    submitted_assignment = @user.exercise_assignments.order(:id).last
    initial_signature = ReadingNoteExerciseGenerator.exercise_signature(
      question_type: exercise.fetch("t"),
      clef_id: exercise.fetch("c"),
      pitch_name: exercise["p"],
      key_signature_id: exercise["k"]
    )

    post submit_app_playground_answer_path,
         params: {
           activity: "leitura",
           selected_option_id: exercise.fetch("a"),
           assignment_id: submitted_assignment.public_id,
           attempt_token: submitted_assignment.answer_token,
           clef_mode: "alto",
           question_mode: "note_name",
           season_mode: "level_2"
         },
         headers: { "Turbo-Frame" => "reading_playground" }

    assert_response :success
    refute_includes response.body, initial_signature
    assert_includes response.body, "data-reading-signature"
    assert_includes response.body, "Resposta correta"
  end

  test "accepts the immediately previous unanswered exercise instead of showing a synchronization error" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura", clef_mode: "alto", question_mode: "note_name", season_mode: "level_1")
    assert_response :success

    previous_exercise = reading_state.fetch("exercise")
    previous_assignment = @user.exercise_assignments.order(:id).last
    previous_signature = ReadingNoteExerciseGenerator.exercise_signature(
      question_type: previous_exercise.fetch("t"),
      clef_id: previous_exercise.fetch("c"),
      pitch_name: previous_exercise["p"],
      key_signature_id: previous_exercise["k"]
    )

    get app_playground_path(activity: "leitura", clef_mode: "alto", question_mode: "note_name", season_mode: "level_1", refresh: 1)
    assert_response :success

    post submit_app_playground_answer_path,
         params: {
           activity: "leitura",
           selected_option_id: previous_exercise.fetch("a"),
           assignment_id: previous_assignment.public_id,
           attempt_token: previous_assignment.answer_token,
           clef_mode: "alto",
           question_mode: "note_name",
           season_mode: "level_1"
         },
         headers: { "Turbo-Frame" => "reading_playground" }

    assert_response :success
    refute_includes response.body, "Atualize a rodada atual"
    assert_includes response.body, "Resposta correta"
  end
end
