require "test_helper"

class DashboardRefinementTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "dashboard-refined@example.test", password: "password123", full_name: "Marina", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "empty dashboard provides real practice links and zero totals" do
    get app_dashboard_path
    assert_response :success
    assert_select ".study-index__entry", count: 4
    assert_select ".dashboard-start a[href='#{app_pratica_path}']", count: 1
    assert_select "[data-testid=resume-practice]", count: 0
    assert_select "[data-testid=attempt-count]", text: "0"
    assert_select "[data-testid=xp-total]", text: "0"
    assert_select "[data-testid=empty-history]", count: 1
  end

  test "return action preserves the latest dictation instrument without disclosing correction metadata" do
    exercise = MelodicDictationExerciseGenerator.new(instrument: "organ").call
    assignment = ExerciseAssignment.issue!(user: @user, area: "percepcao", exercise:)
    ExerciseSubmission.call(user: @user, area: "percepcao", assignment_id: assignment.public_id, attempt_token: assignment.answer_token, selected_option_id: exercise[:correct_option_id], playback_status: "ready")
    get app_dashboard_path
    assert_select "a[data-testid=resume-practice][href='#{app_playground_path(activity: 'percepcao', instrument: 'organ', question_mode: 'melodic_dictation')}']", count: 1
    assert_select "[data-testid=attempt-count]", text: "1"
    assert_select "[data-testid=xp-total]", text: "20"
    assert_select ".study-journal [data-testid=history-row]", count: 1
    assert_select "[name=correct_option_id], [data-correct-option-id]", count: 0
  end
  test "return to harmony keeps the selected chord structure" do
    exercise = HarmonyExerciseGenerator.new(chord_structure: "tetrad", question_mode: "quality").call
    assignment = ExerciseAssignment.issue!(user: @user, area: "harmonia", exercise:)
    ExerciseSubmission.call(user: @user, area: "harmonia", assignment_id: assignment.public_id, attempt_token: assignment.answer_token, selected_option_id: exercise[:correct_option_id], playback_status: "ready")
    get app_dashboard_path
    assert_select "[data-testid=resume-practice]" do |links|
      assert_equal "tetrad", Rack::Utils.parse_query(URI.parse(links.first["href"]).query)["chord_structure"]
    end
  end

  test "return to metrical rhythm keeps mixed selection rather than its sampled mode" do
    exercise = MetricalRhythmExerciseGenerator.new(level: 4, meter_id: "5-8-2-3", activity_mode: "mixed").call
    assignment = ExerciseAssignment.issue!(user: @user, area: "ritmica", exercise:)
    ExerciseSubmission.call(user: @user, area: "ritmica", assignment_id: assignment.public_id, attempt_token: assignment.answer_token, selected_option_id: exercise[:correct_option_id], playback_status: "ready")
    get app_dashboard_path
    assert_select "[data-testid=resume-practice]" do |links|
      query = Rack::Utils.parse_query(URI.parse(links.first["href"]).query)
      assert_equal "mixed", query["activity_mode"]
      assert_equal "4", query["level"]
      assert_equal "5-8-2-3", query["meter_id"]
    end
  end

end
