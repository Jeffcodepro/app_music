require "test_helper"

class PracticeMilestoneTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "practice-milestone@example.test", password: "password123", full_name: "Prática", plan: "Pulso")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "all four playgrounds use a single native disclosure with real named links" do
    %w[leitura percepcao ritmica harmonia].each do |area|
      get app_playground_path(activity: area)
      assert_response :success
      assert_select "details.practice-switcher:not([open])", count: 1
      assert_select "summary[aria-controls=practice-destinations]", count: 1
      assert_select "#practice-destinations[aria-label='Áreas de prática'] a", count: 4
      assert_select "#practice-destinations a[aria-current=page][href='#{app_playground_path(activity: area)}']", count: 1
      assert_select "#practice-destinations a[data-turbo-frame=_top]", count: 4
      assert_select "[role=tab], [role=tablist], .playground-activity-grid", count: 0
    end
  end

  test "practice keeps four destinations without an instruction sidebar" do
    get app_pratica_path
    assert_select ".study-index__entry", count: 4
    assert_select ".listening-note", count: 0
    assert_select ".practice-history-link[href='#{app_practice_result_path}']", count: 1
    refute_match(/iniciante|avançado|intermediário|proficiência/i, response.body)
  end

  test "trails keep their existing study cards outside this approval milestone" do
    get app_trilhas_path
    assert_response :success
    assert_select "body.study-editorial", count: 0
    assert_select ".study-areas .study-area", count: 4
    assert_select ".study-index__list", count: 0
  end

  test "dashboard limits recent attempts to five and history to fifty without leaking another account" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(23)).call
    51.times { credit(@user, exercise) }
    other = User.create!(email: "other-ledger@example.test", password: "password123", full_name: "Outra conta", plan: "Pulso")
    credit(other, exercise)
    get app_dashboard_path
    assert_select "[data-testid=history-row]", count: 5
    assert_select "[data-testid=attempt-count]", text: "51"
    assert_select "[data-testid=xp-total]", text: "1020"
    get app_practice_result_path
    assert_select "[data-testid=history-row]", count: 50
    assert_select "[data-testid=correct-count]", text: "51"
    assert_select "time[datetime]", count: 50
    assert_select ".history-ledger__xp", text: /20.*XP nesta tentativa/, count: 50
    assert_select ".history-totals", text: /Totais de todas as respostas/
  end

  private

  def credit(user, exercise)
    assignment = ExerciseAssignment.issue!(user:, area: "leitura", exercise:)
    ExerciseSubmission.call(user:, area: "leitura", assignment_id: assignment.public_id,
      attempt_token: assignment.answer_token, selected_option_id: exercise.fetch(:correct_option_id))
  end
end
