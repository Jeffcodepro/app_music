require "test_helper"
require "uri"

class PerceptionContinuationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "continue-dictation@example.test", password: "password123", full_name: "Continuidade", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "interval and dictation use identical instrument cards and preserve the selected instrument" do
    %w[interval melodic_dictation].each do |mode|
      get app_playground_path(activity: "percepcao", question_mode: mode, instrument: "organ")
      assert_response :success
      assert_select ".playground-option-grid .playground-select-card", count: 5
      assert_select ".playground-select-card.is-selected input[name=instrument][value=organ][checked]", count: 1
      assert_select "select[name=instrument]", count: 0
      assert_select ".playground-select-card__icon img", count: 5
      assert_select ".playground-select-card__icon svg", count: 0
    end
  end

  test "after a correct dictation the primary action advances and plays a fresh assignment once" do
    get app_playground_path(activity: "percepcao", question_mode: "melodic_dictation", instrument: "flute")
    assignment = @user.exercise_assignments.last
    post submit_app_playground_answer_path, params: {
      activity: "percepcao", question_mode: "melodic_dictation", instrument: "flute",
      assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
      selected_option_id: assignment.exercise_payload["correct_option_id"], playback_status: "ready"
    }, headers: { "Turbo-Frame" => "perception_playground" }
    assert_response :success
    assert_select ".playground-player-controls a[aria-label='Próximo ditado e tocar'][data-turbo-frame=perception_playground]", count: 1
    assert_select ".playground-player-controls button[data-action='melody-player#repeat']", count: 1
    assert_select ".playground-player-controls button[data-action='melody-player#playBlocked']", count: 0
    url = css_select(".playground-player-controls a").first["href"]
    query = Rack::Utils.parse_query(URI.parse(url).query)
    assert_equal "melodic_dictation", query["question_mode"]
    assert_equal "flute", query["instrument"]
    assert_difference "ExerciseAssignment.count", 1 do
      get url, headers: { "Turbo-Frame" => "perception_playground" }
    end
    assert_response :success
    next_assignment = @user.exercise_assignments.last
    refute_equal assignment.public_id, next_assignment.public_id
    assert_select "[data-melody-player-auto-play-value=true][data-melody-player-exercise-signature-value='#{next_assignment.public_id}']", count: 1
    assert_select ".melody-options button:not([disabled])", count: 4
    assert_select ".playground-feedback", count: 0
    assert_equal 20, @user.study_activities.sum(:xp_earned)
  end

  test "explicit next and play keeps autoplay with preserved preferences while settings stay silent" do
    %w[interval melodic_dictation].each do |mode|
      player = mode == "interval" ? "interval" : "melody"
      get app_playground_path(activity: "percepcao", question_mode: mode, instrument: "flute", direction_mode: "descending", refresh: 1, autoplay: 1)
      assert_response :success
      assert_select "[data-#{player}-player-auto-play-value=true]", count: 1
      get app_playground_path(activity: "percepcao", question_mode: mode, instrument: "organ", direction_mode: "descending")
      assert_select "[data-#{player}-player-auto-play-value=false]", count: 1
    end
  end
end
