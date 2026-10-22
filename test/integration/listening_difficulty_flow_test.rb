require "test_helper"

class ListeningDifficultyFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "listening-levels@example.test", password: "password123", full_name: "Estudante", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "all listening levels render and bare reload preserves exact assignment and audio" do
    [["percepcao", "interval"], ["percepcao", "melodic_dictation"], ["harmonia", "mixed"]].each do |area, mode|
      (1..4).each do |level|
        get app_playground_path(activity: area, question_mode: mode, level:, instrument: "organ", refresh: 1)
        assert_response :success
        assignment = @user.exercise_assignments.last
        payload = assignment.exercise_payload
        assert_equal level, payload["level"]
        assert_select "select[name=level] option[selected][value='#{level}']", count: 1
        assert_select "input[name=level][value='#{level}']", count: 4
        assert_select "input[name=correct_option_id], input[name=xp_earned]", count: 0
        assert_select ".voiced-score", count: 4 if mode == "melodic_dictation"
        assert_no_difference "ExerciseAssignment.count" do
          get app_playground_path(activity: area)
          assert_response :success
        end
        assert_includes response.body, assignment.public_id
        assert_equal payload, assignment.reload.exercise_payload
        instrument = mode == "melodic_dictation" && level == 4 ? "piano" : "organ"
        assert_select "input[name=instrument][value=#{instrument}][checked]", count: 1
      end
    end
  end

  test "answer uses persisted difficulty and next round retains it despite forged level" do
    [["percepcao", "melodic_dictation", "perception_playground"], ["harmonia", "quality", "harmony_playground"]].each do |area, mode, frame|
      get app_playground_path(activity: area, question_mode: mode, level: 3, instrument: "flute")
      assignment = @user.exercise_assignments.last
      post submit_app_playground_answer_path, params: {
        activity: area, question_mode: mode, level: 1, instrument: "flute", assignment_id: assignment.public_id,
        attempt_token: assignment.answer_token, selected_option_id: assignment.exercise_payload["correct_option_id"], playback_status: "ready"
      }, headers: { "Turbo-Frame" => frame }
      assert_response :success
      assert_select(area == "harmonia" ? ".playground-previous-result" : ".playground-feedback.is-correct", count: 1)
      assert_select "select[name=level] option[selected][value='3']", count: 1
      assert_equal 20, assignment.study_activity.xp_earned
      assert_equal 3, @user.exercise_assignments.last.exercise_payload["level"]
      get app_playground_path(activity: area, refresh: 1)
      assert_response :success
      assert_equal 3, @user.exercise_assignments.last.exercise_payload["level"]
    end
  end

  test "harmony instrument selection survives bare reload and incompatible modes visibly adjust" do
    get app_playground_path(activity: "harmonia", level: 4, question_mode: "progression", chord_structure: "tetrad")
    get app_playground_path(activity: "harmonia", instrument: "clarinet")
    assignment = @user.exercise_assignments.last
    assert_equal "clarinet", assignment.exercise_payload["instrument"]
    assert_no_difference "ExerciseAssignment.count" do
      get app_playground_path(activity: "harmonia")
    end
    assert_select "input[name=instrument][value=clarinet][checked]", count: 1
    get app_playground_path(activity: "harmonia", level: 1)
    assert_response :success
    assert_select "[role=status]", text: /ajustadas ao nível/
    payload = @user.exercise_assignments.last.exercise_payload
    assert_equal "triad", payload["chord_structure"]
    assert_includes %w[quality scale_degree], payload["question_type"]
  end

  test "sidebar disclosure contains identity settings and the authenticated DELETE logout" do
    get app_dashboard_path
    assert_select ".sidebar-bottom details.account-menu > summary[aria-expanded=false]", count: 1
    assert_select ".account-menu__identity", text: /#{Regexp.escape(@user.email)}/
    assert_select ".account-menu__panel a[href='#{app_dashboard_path}']", text: "Painel do membro"
    assert_select ".account-menu__panel a[href='#{app_perfil_path}']", text: "Configurações"
    assert_select ".account-menu__panel form[action='#{destroy_user_session_path}'] input[name=_method][value=delete]", count: 1
    assert_select ".account-menu__panel button[aria-label='Sair da conta']", text: /Sair/
    delete destroy_user_session_path
    get app_dashboard_path
    assert_redirected_to new_user_session_path
  end
end
