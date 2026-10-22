require "test_helper"

class DailyVisitConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent page visits persist a single day and never award credit" do
    user = User.create!(email: "visits-race@example.test", password: "password123", full_name: "Visitas", plan: "Pulso")
    DailyVisit.column_names
    start = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          DailyVisit.record_for(user, at: Time.utc(2026, 10, 20, 12))
        end
      end
    end
    2.times { start << true }
    threads.each(&:value)
    assert_equal 1, user.daily_visits.count
    assert_equal 0, user.study_activities.sum(:xp_earned)
  ensure
    threads&.each(&:join)
    user&.destroy!
  end
end
