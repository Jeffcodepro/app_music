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

  test "renders the reading playground for an authenticated user" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura")

    assert_response :success
    assert_includes response.body, "Playground de leitura"
    assert_includes response.body, "Tipo de pergunta"
    assert_includes response.body, "<svg"
  end

  test "stores a compact reading exercise in session" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura", clef_mode: "alto", question_mode: "note_name")

    stored_exercise = @request.session[:reading_note_exercise]&.to_h

    assert_equal %w[a c i m o p q t], stored_exercise.keys.sort
    assert_equal 4, stored_exercise.fetch("o").size
    refute_includes stored_exercise.keys, "options"
    refute_includes stored_exercise.keys, "pitch_label"
  end

  test "correct answer generates a fresh reading round in the turbo frame" do
    post user_session_path, params: { user: { email: @user.email, password: @password } }
    follow_redirect! if response.redirect?

    get app_playground_path(activity: "leitura", clef_mode: "alto", question_mode: "note_name")
    assert_response :success

    exercise = @request.session[:reading_note_exercise]&.to_h
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
           exercise_signature: initial_signature,
           clef_mode: "alto",
           question_mode: "note_name"
         },
         headers: { "Turbo-Frame" => "reading_playground" }

    assert_response :success
    refute_includes response.body, initial_signature
    assert_includes response.body, "data-reading-signature"
    assert_includes response.body, "Resposta correta"
  end
end
