require "test_helper"
require "timeout"

class ExerciseSubmissionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = User.create!(email: "concurrency-#{SecureRandom.hex(6)}@example.com", password: "password123", full_name: "Concurrent", plan: "Pulso")
    @exercise = ReadingNoteExerciseGenerator.new(random: Random.new(0), question_mode: "note_name").call
    @assignment = ExerciseAssignment.issue!(user: @user, area: "leitura", exercise: @exercise)
  end

  teardown do
    @user&.destroy!
  end

  test "independent connections serialize simultaneous repeated submissions" do
    ready = Queue.new
    start = Queue.new
    token = @assignment.answer_token
    workers = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          ExerciseSubmission.call(user: @user, area: "leitura", assignment_id: @assignment.public_id,
                                  attempt_token: token, selected_option_id: @exercise[:correct_option_id])
        end
      end
    end
    results = Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { start << true }
      workers.map(&:value)
    end
    assert_equal [false, true], results.map(&:duplicate).sort_by { |value| value ? 1 : 0 }
    assert_equal 1, @assignment.exercise_attempts.count
    assert_equal 1, @user.study_activities.count
    assert_equal 20, @user.study_activities.sum(:xp_earned)
  ensure
    workers&.each { |worker| worker.kill if worker.alive? }
    workers&.each(&:join)
  end

  test "database independently rejects duplicate attempt and duplicate activity" do
    token = @assignment.answer_token
    ExerciseSubmission.call(user: @user, area: "leitura", assignment_id: @assignment.public_id,
                            attempt_token: token, selected_option_id: @exercise[:correct_option_id])
    assert_raises(ActiveRecord::RecordNotUnique) do
      @assignment.exercise_attempts.create!(attempt_token: token, selected_option_id: "c", correct: true, xp_earned: 20)
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      StudyActivity.create!(user: @user, exercise_assignment: @assignment, area: "leitura", xp_earned: 20,
                            minutes_practiced: 3, occurred_on: Date.current)
    end
  end

  test "simultaneous conflicting answers cannot reuse the same token" do
    ready = Queue.new
    start = Queue.new
    token = @assignment.answer_token
    wrong = (@exercise[:options].pluck(:id) - [@exercise[:correct_option_id]]).first
    workers = [wrong, @exercise[:correct_option_id]].map do |option|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          ExerciseSubmission.call(user: @user, area: "leitura", assignment_id: @assignment.public_id,
                                  attempt_token: token, selected_option_id: option)
        rescue ExerciseSubmission::Rejected
          :rejected
        end
      end
    end
    results = Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { start << true }
      workers.map(&:value)
    end
    assert_equal 1, results.count(:rejected)
    assert_equal 1, @assignment.exercise_attempts.count
    assert_equal 1, @user.study_activities.count
    assert_includes [6, 20], @user.study_activities.sum(:xp_earned)
  ensure
    workers&.each { |worker| worker.kill if worker.alive? }
    workers&.each(&:join)
  end
end
