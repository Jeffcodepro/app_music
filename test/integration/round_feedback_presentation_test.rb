require "test_helper"

class RoundFeedbackPresentationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "round-feedback@example.test", password: "password123", full_name: "Rodadas", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  { "leitura" => "reading", "ritmica" => "rhythm", "harmonia" => "harmony" }.each do |area, frame|
    [false, true].each do |turbo|
      test "#{area} #{turbo ? 'Turbo' : 'HTTP'} keeps wrong feedback in its round and separates success when the round changes" do
        get app_playground_path(activity: area)
        first = @user.exercise_assignments.order(:id).last
        wrong = first.exercise_payload.fetch("options").find { |option| option.fetch("id") != first.exercise_payload.fetch("correct_option_id") }.fetch("id")
        submit(first, wrong, turbo:, frame:)
        assert_select ".playground-feedback.is-incorrect", count: 1
        assert_select "input[name=assignment_id][value='#{first.public_id}']", count: 4
        assert_select ".playground-previous-result", count: 0
        first.reload
        assert_equal 6, first.study_activity.xp_earned
        submit(first, first.exercise_payload.fetch("correct_option_id"), turbo:, frame:)
        second_id = css_select("input[name=assignment_id]").first["value"]
        refute_equal first.public_id, second_id
        assert_select ".playground-feedback", count: 0, message: "Current question must never display the previous question's feedback"
        assert_select ".playground-previous-result[role=status]", text: /Rodada anterior concluída.*Resposta correta.*Nova rodada pronta/m
        assert_select ".perception-option[disabled]", count: 0
        assert_equal 20, first.reload.study_activity.xp_earned
        second = @user.exercise_assignments.find_by!(public_id: second_id)
        second_wrong = second.exercise_payload.fetch("options").find { |option| option.fetch("id") != second.exercise_payload.fetch("correct_option_id") }.fetch("id")
        submit(second, second_wrong, turbo:, frame:)
        assert_select "input[name=assignment_id][value='#{second_id}']", count: 4
        assert_select ".playground-feedback.is-incorrect[role=status][aria-live=polite]", count: 1
        assert_select ".playground-previous-result", count: 0
        get app_playground_path(activity: area, refresh: 1)
        assert_select ".playground-feedback, .playground-previous-result", count: 0
        assert_equal 3, ExerciseAttempt.joins(:exercise_assignment).where(exercise_assignments: { user_id: @user.id }).count
      end
    end

    test "#{area} explicit refresh with pending HTTP flash cannot attach old feedback to the next assignment" do
      get app_playground_path(activity: area)
      first = @user.exercise_assignments.order(:id).last
      post submit_app_playground_answer_path, params: answer_params(first, first.exercise_payload.fetch("correct_option_id"))
      assert_response :redirect
      get app_playground_path(activity: area, refresh: 1)
      assert_select ".playground-feedback", count: 0
      assert_select ".playground-previous-result", text: /Rodada anterior concluída/
      refute_equal first.public_id, css_select("input[name=assignment_id]").first["value"]
    end
  end

  private

  def answer_params(assignment, option_id)
    { activity: assignment.area, assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
      selected_option_id: option_id, playback_status: "ready" }
  end

  def submit(assignment, option_id, turbo:, frame:)
    post submit_app_playground_answer_path, params: answer_params(assignment, option_id),
      headers: turbo ? { "Turbo-Frame" => "#{frame}_playground" } : {}
    if turbo
      assert_response :success
      assert_select "turbo-frame##{frame}_playground", count: 1
    else
      assert_response :redirect
      follow_redirect!
      assert_response :success
    end
  end
end
