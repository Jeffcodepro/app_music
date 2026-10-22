require "test_helper"

class MetricalRhythmFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "meter-flow@example.test", password: "password123", full_name: "Métrica", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "compound setting survives reload rehydration answer and next question" do
    params = { activity: "ritmica", level: 2, meter_id: "6-8", activity_mode: "pulse" }
    get app_playground_path(**params)
    assert_response :success
    assignment = @user.exercise_assignments.last
    assert_equal "meter-v1", assignment.exercise_payload["rhythm_format"]
    assert_equal 2, assignment.exercise_payload["measure_count"]
    assert_select "[data-rhythm-player-meter-value]", count: 1
    assert_select "select[name=level] option[selected][value='2']", count: 1
    assert_select "select[name=meter_id] option[selected][value='6-8']", count: 1
    assert_select ".exercise-context", text: /semínima pontuada/
    assert_select ".rhythm-options [name=level][value='2']", count: 4
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(**params)
    end
    assert_select "[data-rhythm-player-exercise-signature-value='#{assignment.public_id}']", count: 1
    post submit_app_playground_answer_path, params: params.merge(
      assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
      selected_option_id: assignment.exercise_payload["correct_option_id"], playback_status: "ready"
    ), headers: { "Turbo-Frame" => "rhythm_playground" }
    assert_response :success
    assert_select ".playground-previous-result", count: 1
    assert_select "[data-rhythm-player-meter-value]", count: 1
    assert_equal 20, @user.study_activities.sum(:xp_earned)
    next_assignment = @user.exercise_assignments.last
    refute_equal assignment.id, next_assignment.id
    assert_equal "6-8", next_assignment.exercise_payload["meter_id"]
  end

  test "mixed mode refreshes when level or grouping changes and levels restrict the catalog" do
    get app_playground_path(activity: "ritmica", level: 4, meter_id: "5-8-2-3")
    first = @user.exercise_assignments.last
    get app_playground_path(activity: "ritmica", level: 4, meter_id: "5-8-3-2")
    assert_response :success
    refute_equal first.id, @user.exercise_assignments.last.id
    assert_equal [3,2], @user.exercise_assignments.last.exercise_payload["meter"]["groups"]
    get app_playground_path(activity: "ritmica", level: 1, meter_id: "5-8-3-2")
    assert_select "select[name=meter_id] option", count: 4
    assert_equal "4-4", @user.exercise_assignments.last.exercise_payload["meter_id"]
  end

  test "returning through a bare practice link keeps the active meter and preferences" do
    get app_playground_path(activity: "ritmica", level: 4, meter_id: "5-8-2-3", activity_mode: "precision")
    assignment = @user.exercise_assignments.last
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(activity: "ritmica")
    end
    assert_select "select[name=level] option[selected][value='4']", count: 1
    assert_select "select[name=meter_id] option[selected][value='5-8-2-3']", count: 1
    assert_select ".rhythm-options input[name=meter_id][value='5-8-2-3']", count: 4
    assert_select "input[name=activity_mode][value=precision][checked]", count: 1
    assert_select ".rhythm-score-scroll[tabindex='0'][role=region]", count: 4
    assert_select "button [tabindex]", count: 0
    assert_select "[data-rhythm-player-exercise-signature-value='#{assignment.public_id}']", count: 1
  end

  test "switching between mixed and its resolved mode records the requested preference" do
    preferences = { activity: "ritmica", level: 2, meter_id: "6-8" }
    get app_playground_path(**preferences, activity_mode: "mixed")
    mixed_assignment = @user.exercise_assignments.last
    resolved_mode = mixed_assignment.exercise_payload.fetch("activity_mode")

    get app_playground_path(**preferences, activity_mode: resolved_mode)
    explicit_assignment = @user.exercise_assignments.last
    refute_equal mixed_assignment.id, explicit_assignment.id
    assert_equal resolved_mode, explicit_assignment.exercise_payload["requested_activity_mode"]
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(activity: "ritmica")
    end
    assert_select "input[name=activity_mode][value=#{resolved_mode}][checked]", count: 1

    get app_playground_path(**preferences, activity_mode: "mixed")
    refute_equal explicit_assignment.id, @user.exercise_assignments.last.id
    assert_equal "mixed", @user.exercise_assignments.last.exercise_payload["requested_activity_mode"]
  end

  test "legacy four four assignments stay valid without opting into new settings" do
    get app_playground_path(activity: "ritmica", activity_mode: "subdivision")
    assignment = @user.exercise_assignments.last
    refute assignment.exercise_payload.key?("rhythm_format")
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(activity: "ritmica", activity_mode: "subdivision")
    end
    assert_select "[data-rhythm-player-exercise-signature-value='#{assignment.public_id}']", count: 1
  end

  test "mixed meter persists through reload wrong answer and advances only on a new round" do
    preferences = { activity: "ritmica", level: 2, meter_id: "mixed", activity_mode: "precision" }
    get app_playground_path(**preferences)
    first = @user.exercise_assignments.last
    assert_equal "mixed", first.exercise_payload["requested_meter_id"]
    assert_select "select[name=meter_id] option[value=mixed][selected]", count: 1
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(activity: "ritmica")
      get app_playground_path(**preferences)
    end
    wrong = first.exercise_payload["options"].find { |o| o["id"] != first.exercise_payload["correct_option_id"] }
    post submit_app_playground_answer_path, params: preferences.merge(assignment_id: first.public_id, attempt_token: first.answer_token,
      selected_option_id: wrong["id"], playback_status: "ready"), headers: { "Turbo-Frame" => "rhythm_playground" }
    assert_response :success
    assert_equal first.id, @user.exercise_assignments.last.id
    assert_select ".rhythm-options input[name=meter_id][value=mixed]", count: 4
    get app_playground_path(**preferences, refresh: 1)
    refute_equal first.id, @user.exercise_assignments.last.id
    assert_equal "mixed", @user.exercise_assignments.last.exercise_payload["requested_meter_id"]
    assert_equal 6, @user.study_activities.sum(:xp_earned)
  end
end
