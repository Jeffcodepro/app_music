require "test_helper"

class StudyCalendarTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "calendar@example.test", password: "password123", full_name: "Calendário", plan: "Pulso")
  end

  test "access dates are unique per user and use Brasilia midnight" do
    2.times { DailyVisit.record_for(@user, at: Time.utc(2026, 10, 2, 1)) }
    assert_equal [Date.new(2026, 10, 1)], @user.daily_visits.pluck(:visited_on)
    assert_raises(ActiveRecord::RecordNotUnique) do
      DailyVisit.transaction(requires_new: true) { @user.daily_visits.create!(visited_on: Date.new(2026, 10, 1)) }
    end
  end

  test "calendar scopes access and practice to user and month including actual attempt dates" do
    DailyVisit.record_for(@user, at: Time.utc(2026, 10, 2, 1))
    other = User.create!(email: "other-calendar@example.test", password: "password123", full_name: "Outro", plan: "Pulso")
    DailyVisit.record_for(other, at: Time.utc(2026, 10, 9, 12))
    other.study_activities.create!(area: "leitura", occurred_on: Date.new(2026, 10, 9))
    @user.study_activities.create!(area: "leitura", occurred_on: Date.new(2026, 10, 4))
    assignment = ExerciseAssignment.issue!(user: @user, area: "leitura", exercise: ReadingNoteExerciseGenerator.new.call)
    assignment.exercise_attempts.create!(attempt_token: SecureRandom.uuid, selected_option_id: "reference", correct: false, xp_earned: 0, created_at: Time.utc(2026, 10, 6, 1))
    calendar = StudyCalendar.new(@user, month: "2026-10")
    assert_equal [Date.new(2026, 10, 1)], calendar.visits.keys
    assert_equal [Date.new(2026, 10, 4), Date.new(2026, 10, 5)], calendar.practice_counts.keys.sort
    assert_equal 2, calendar.total_practice_days
    assert_equal 5, calendar.weeks.size
    assert_equal 6, StudyCalendar.new(@user, month: "2026-08").weeks.size
    assert_empty StudyCalendar.new(@user, month: "2026-11").practice_counts
    assert_equal Time.current.in_time_zone(DailyVisit::ZONE).to_date.beginning_of_month, StudyCalendar.new(@user, month: "bad").month
  end
end
