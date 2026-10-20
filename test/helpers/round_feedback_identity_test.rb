require "test_helper"

class RoundFeedbackIdentityTest < ActiveSupport::TestCase
  include PlatformUiHelper

  test "same content never makes different assignments the same round" do
    %w[leitura ritmica harmonia].each do |area|
      exercise = { assignment_id: "current-uuid", signature: "same-content", attempt_token: "new-token" }
      current = { activity: area, assignment_id: "current-uuid", exercise_signature: "same-content", correct: false, attempt_token: "old-token" }
      assert feedback_for_round?(current, exercise, area:)
      refute completed_previous_round?(current, exercise, area:)
      previous = current.merge(assignment_id: "previous-uuid", correct: true)
      refute feedback_for_round?(previous, exercise, area:)
      assert completed_previous_round?(previous, exercise, area:)
      [nil, {}, current.except(:assignment_id), current.merge(assignment_id: ""), current.merge(activity: "percepcao")].each do |invalid|
        refute feedback_for_round?(invalid, exercise, area:)
        refute completed_previous_round?(invalid, exercise, area:)
      end
      refute feedback_for_round?(current, exercise.except(:assignment_id), area:)
      refute completed_previous_round?(previous, exercise.except(:assignment_id), area:)
    end
  end
end
