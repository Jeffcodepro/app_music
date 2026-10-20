require "test_helper"

class MelodicDictationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "dictation@example.test", password: "password123", full_name: "Ditado", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    get app_playground_path(activity: "percepcao", question_mode: "melodic_dictation")
    @assignment = @user.exercise_assignments.last
  end

  test "four scores keep identity and mode across reload and Turbo settings" do
    assert_response :success
    assert_select "form.playground-controls[data-turbo-action=replace]", count: 1
    assert_equal "melodic_dictation", @assignment.exercise_payload["question_type"]
    assert_select "[data-controller='melody-player preferences']", count: 1
    assert_select ".melody-options button", count: 4
    assert_select ".melody-options svg", count: 4
    assert_select ".melody-options input[name=question_mode][value=melodic_dictation]", count: 4
    assert_select "[name=correct_option_id], [data-correct], [name=xp_earned]", count: 0
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(activity: "percepcao", question_mode: "melodic_dictation")
    end
    assert_select "[data-melody-player-exercise-signature-value='#{@assignment.public_id}']", count: 1
    get app_playground_path(activity: "percepcao", question_mode: "interval")
    assert_select "[data-controller='interval-player preferences']", count: 1
  end

  test "completed listening credits once and replay stays in dictation" do
    answer(@assignment.exercise_payload["correct_option_id"])
    assert_response :success
    assert_select ".playground-feedback.is-correct", count: 1
    assert_select ".melody-options button[disabled]", count: 4
    assert_equal 20, @user.study_activities.sum(:xp_earned)
    assert_no_difference "ExerciseAttempt.count" do
      answer(@assignment.exercise_payload["correct_option_id"], token: @submitted_token)
    end
    assert_response :see_other
    follow_redirect!
    assert_select "[data-controller='melody-player preferences']", count: 1
    assert_equal 20, @user.study_activities.sum(:xp_earned)
  end

  test "missing playback and fabricated option never credit; retry remains capped" do
    answer("missing")
    assert_response :see_other
    assert_equal 0, ExerciseAttempt.where(exercise_assignment: @user.exercise_assignments).count
    answer(@assignment.exercise_payload["correct_option_id"], playback: "")
    assert_response :see_other
    assert_equal 0, @user.study_activities.sum(:xp_earned)
    wrong = @assignment.exercise_payload["options"].find { |o| o["id"] != @assignment.exercise_payload["correct_option_id"] }["id"]
    answer(wrong)
    assert_response :success
    assert_select ".playground-feedback.is-incorrect", count: 1
    assert_equal 6, @user.study_activities.sum(:xp_earned)
    answer(@assignment.exercise_payload["correct_option_id"])
    assert_equal 20, @user.study_activities.sum(:xp_earned)
  end

  test "pending dictation feedback cannot disable a new interval or refreshed round" do
    post submit_app_playground_answer_path, params: {
      activity: "percepcao", question_mode: "melodic_dictation", assignment_id: @assignment.public_id,
      attempt_token: @assignment.answer_token, selected_option_id: @assignment.exercise_payload["correct_option_id"], playback_status: "ready"
    }
    assert_response :redirect
    get app_playground_path(activity: "percepcao", question_mode: "interval", refresh: 1)
    assert_response :success
    assert_select ".perception-options button:not([disabled])", count: 4
    assert_select ".playground-feedback, .is-last-answer", count: 0
  end

  test "neutral rejection preserves flute dictation and its assignment" do
    get app_playground_path(activity: "percepcao", question_mode: "melodic_dictation", instrument: "flute")
    assignment = @user.exercise_assignments.last
    ["", "missing"].each do |failure|
      assert_no_difference "ExerciseAssignment.count" do
        post submit_app_playground_answer_path, params: {
          activity: "percepcao", question_mode: "melodic_dictation", instrument: "flute",
          assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
          selected_option_id: failure == "missing" ? failure : assignment.exercise_payload["correct_option_id"], playback_status: ""
        }
        assert_response :see_other
        follow_redirect!
        assert_response :success
      end
      assert_select "[data-melody-player-exercise-signature-value='#{assignment.public_id}'][data-melody-player-instrument-value=flute]", count: 1
    end
    assert_equal 0, @user.study_activities.sum(:xp_earned)
  end

  private

  def answer(option, token: nil, playback: "ready")
    @submitted_token = token || @assignment.reload.answer_token
    post submit_app_playground_answer_path, params: {
      activity: "percepcao", question_mode: "melodic_dictation", instrument: "piano",
      assignment_id: @assignment.public_id, attempt_token: @submitted_token, selected_option_id: option, playback_status: playback
    }, headers: { "Turbo-Frame" => "perception_playground" }
  end
end
