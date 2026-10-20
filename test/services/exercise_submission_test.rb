require "test_helper"
require "minitest/mock"

class ExerciseSubmissionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "integrity@example.com", password: "password123", full_name: "Integrity", plan: "Pulso")
    @exercise = ReadingNoteExerciseGenerator.new(random: Random.new(0), question_mode: "note_name").call
  end

  def assignment
    @assignment ||= ExerciseAssignment.issue!(user: @user, area: "leitura", exercise: @exercise)
  end

  def submit(option:, token: assignment.answer_token, user: @user, **extra)
    ExerciseSubmission.call(user:, area: "leitura", assignment_id: assignment.public_id,
                            attempt_token: token, selected_option_id: option, **extra)
  end

  test "same token cannot grant credit twice or change its answer" do
    token = assignment.answer_token
    first = submit(option: @exercise[:correct_option_id], token:)
    duplicate = submit(option: @exercise[:correct_option_id], token:)
    assert first.correct
    assert duplicate.duplicate
    assert_equal 1, assignment.exercise_attempts.count
    assert_equal 20, @user.study_activities.sum(:xp_earned)
    assert_raises(ExerciseSubmission::Rejected) { submit(option: "unknown", token:) }
  end

  test "training retries retain one activity and a maximum of twenty XP" do
    wrong = (@exercise[:options].pluck(:id) - [@exercise[:correct_option_id]]).first
    submit(option: wrong)
    assert_equal 6, @user.study_activities.sum(:xp_earned)
    submit(option: wrong, token: assignment.reload.answer_token)
    assert_equal 6, @user.study_activities.sum(:xp_earned)
    submit(option: @exercise[:correct_option_id], token: assignment.reload.answer_token)
    assert_equal 20, @user.study_activities.sum(:xp_earned)
    assert_equal 1, @user.study_activities.count
    assert_equal 3, @user.study_activities.sum(:minutes_practiced)
  end

  test "missing identity unknown options expiry and wrong owner do not score" do
    [nil, "", SecureRandom.uuid].each do |token|
      assert_raises(ExerciseSubmission::Rejected) { submit(option: @exercise[:correct_option_id], token:) }
    end
    assert_raises(ExerciseSubmission::Rejected) { submit(option: "unknown") }
    other = User.create!(email: "other@example.com", password: "password123", full_name: "Other", plan: "Pulso")
    assert_raises(ExerciseSubmission::Rejected) { submit(option: @exercise[:correct_option_id], user: other) }
    assignment.update!(expires_at: 1.minute.ago)
    assert_raises(ExerciseSubmission::Rejected) { submit(option: @exercise[:correct_option_id]) }
    assert_equal 0, @user.study_activities.count
  end

  test "inconsistent persisted answer is rejected without a tentative activity" do
    payload = assignment.exercise_payload.deep_dup
    payload["correct_option_id"] = (payload["options"].pluck("id") - [payload["correct_option_id"]]).first
    ExerciseAssignment.where(id: assignment.id).update_all(exercise_payload: payload)
    assert_raises(ExerciseSubmission::Rejected) { submit(option: payload["correct_option_id"]) }
    assert_equal 0, @user.study_activities.count
    assert_equal 0, assignment.exercise_attempts.count
  end

  test "audio failure is not an incorrect musical answer" do
    exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(0)).call
    assigned = ExerciseAssignment.issue!(user: @user, area: "percepcao", exercise:)
    assert_raises(ExerciseSubmission::Rejected) do
      ExerciseSubmission.call(user: @user, area: "percepcao", assignment_id: assigned.public_id,
                              attempt_token: assigned.answer_token, selected_option_id: exercise[:correct_option_id], playback_status: "failed")
    end
    assert_equal 0, assigned.exercise_attempts.count
    assert_equal 0, @user.study_activities.count
  end

  test "an older rules version must be renewed without recording a failed answer" do
    ExerciseAssignment.where(id: assignment.id).update_all(rules_version: "integrity-1")
    assert_no_difference ["ExerciseAttempt.count", "StudyActivity.count"] do
      error = assert_raises(ExerciseSubmission::Rejected) { submit(option: @exercise[:correct_option_id]) }
      assert_includes error.message, "versão"
    end
  end

  test "credit and attempt roll back together" do
    assignment
    StudyActivity.stub(:create!, ->(*) { raise ActiveRecord::RecordInvalid }) do
      assert_raises(ActiveRecord::RecordInvalid) { submit(option: @exercise[:correct_option_id]) }
    end
    assert_equal 0, assignment.exercise_attempts.count
    assert_equal 0, @user.study_activities.count
  end
end
