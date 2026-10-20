require "test_helper"

class PlaygroundAnswerIntegrityTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "http-integrity@example.com", password: "password123", full_name: "HTTP Integrity", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    follow_redirect! if response.redirect?
  end

  def present(area)
    get app_playground_path(activity: area)
    assert_response :success
    @user.exercise_assignments.order(:id).last
  end

  def answer(assignment, **changes)
    post submit_app_playground_answer_path, params: {
      activity: assignment.area, assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
      selected_option_id: assignment.exercise_payload.fetch("correct_option_id"), playback_status: "ready"
    }.merge(changes)
  end

  test "all four areas require opaque assignment and attempt identities and ignore browser credit" do
    %w[leitura percepcao harmonia ritmica].each do |area|
      assignment = present(area)
      assert_select 'input[name="assignment_id"][value=?]', assignment.public_id, count: 4
      assert_select 'input[name="attempt_token"][value=?]', assignment.answer_token, count: 4
      assert_select 'input[name="exercise_signature"]', count: 0
      refute_includes response.body, assignment.exercise_payload.fetch("signature")

      assert_no_difference ["ExerciseAttempt.count", "StudyActivity.count"] do
        answer(assignment, assignment_id: nil, exercise_signature: assignment.exercise_payload["signature"])
        assert_response :see_other
        answer(assignment, attempt_token: nil)
        assert_response :see_other
        answer(assignment, selected_option_id: "not-an-option")
        assert_response :see_other
      end
      assert_difference "ExerciseAttempt.count", 1 do
        answer(assignment, xp_earned: 100_000, correct: false, correct_option_id: "forged")
      end
      assert_equal 20, assignment.study_activity.reload.xp_earned
      assert_no_difference ["ExerciseAttempt.count", "StudyActivity.count", "ExerciseAssignment.count"] do
        answer(assignment)
        assert_response :see_other
      end
    end
  end

  test "cross user expired and musically inconsistent submissions do not score" do
    assignment = present("leitura")
    assert_no_difference ["ExerciseAttempt.count", "StudyActivity.count"] do
      answer(assignment, activity: "harmonia")
      other = User.create!(email: "foreign@example.com", password: "password123", full_name: "Other", plan: "Pulso")
      foreign = ExerciseAssignment.issue!(user: other, area: "leitura", exercise: assignment.exercise_payload)
      answer(foreign)
      assignment.update!(expires_at: 1.second.ago)
      answer(assignment)
    end
    assignment.update!(expires_at: 1.hour.from_now)
    corrupted = assignment.exercise_payload.deep_dup
    corrupted["correct_option_id"] = (corrupted.fetch("options").pluck("id") - [corrupted.fetch("correct_option_id")]).first
    ExerciseAssignment.where(id: assignment.id).update_all(exercise_payload: corrupted)
    assert_no_difference(["ExerciseAttempt.count", "StudyActivity.count"]) { answer(assignment) }
    assert_response :see_other
  end

  test "audio failure is neutral and retrying playback preserves the attempt" do
    %w[percepcao harmonia ritmica].each do |area|
      assignment = present(area)
      assert_no_difference ["ExerciseAttempt.count", "StudyActivity.count"] do
        answer(assignment, playback_status: "failed")
        assert_response :see_other
        assert_includes flash[:alert], "nenhuma resposta foi contabilizada"
      end
      assert_difference "ExerciseAttempt.count", 1 do
        answer(assignment, playback_status: "ready")
      end
    end
  end

  test "an issued exercise remains correctable after cache eviction" do
    assignment = present("leitura")
    token = @request.session[:reading_playground_state_token]
    key = "playground:leitura:#{@user.id}:#{token}"
    StudentHubController::READING_PLAYGROUND_STATE_FALLBACK_STORE.delete(key)
    Rails.cache.delete(key)
    assert_difference "ExerciseAttempt.count", 1 do
      answer(assignment)
    end
    assert_equal 20, assignment.study_activity.reload.xp_earned
  end

  test "client claims cannot turn a wrong musical answer into a correct one" do
    assignment = present("leitura")
    wrong = (assignment.exercise_payload.fetch("options").pluck("id") - [assignment.exercise_payload.fetch("correct_option_id")]).first
    answer(assignment, selected_option_id: wrong, correct: true, xp_earned: 100_000, correct_option_id: wrong)
    assert_equal false, assignment.exercise_attempts.last.correct
    assert_equal 6, assignment.study_activity.xp_earned
  end
end
