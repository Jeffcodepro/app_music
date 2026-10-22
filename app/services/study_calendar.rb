# Coarse access dates and actual practice, in the calendar's explicit local zone.
# Lesson pages are placeholders and deliberately do not create study events.
class StudyCalendar
  ATTEMPT_DATE = "DATE(exercise_attempts.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo')".freeze
  attr_reader :month, :today

  def initialize(user, month: nil, access_available: true)
    @user = user
    @today = Time.current.in_time_zone(DailyVisit::ZONE).to_date
    @month = parse_month(month)
    @access_available = access_available
  end

  def weeks
    (@month.beginning_of_week(:sunday)..@month.end_of_month.end_of_week(:sunday)).to_a.each_slice(7).to_a
  end

  def visits
    return {} unless @access_available
    @visits ||= @user.daily_visits.where(visited_on: @month..@month.end_of_month).pluck(:visited_on).index_with { true }
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
    @access_available = false
    {}
  end

  def visits_available? = @access_available

  def practice_counts
    @practice_counts ||= begin
      zone = Time.find_zone!(DailyVisit::ZONE)
      from = zone.local(@month.year, @month.month, 1)
      to = from.next_month
      counts = attempts.where(created_at: from...to).group(Arel.sql(ATTEMPT_DATE)).count
      @user.study_activities.where(exercise_assignment_id: nil, occurred_on: @month..@month.end_of_month).group(:occurred_on).count.each { |date, count| counts[date] = counts.fetch(date, 0) + count }
      counts
    end
  end

  def total_practice_days
    (attempts.distinct.pluck(Arel.sql(ATTEMPT_DATE)) + @user.study_activities.where(exercise_assignment_id: nil).distinct.pluck(:occurred_on)).uniq.size
  end

  private

  def attempts
    ExerciseAttempt.joins(:exercise_assignment).where(exercise_assignments: { user_id: @user.id })
  end

  def parse_month(value)
    return @today.beginning_of_month unless value.to_s.match?(/\A20\d{2}-(?:0[1-9]|1[0-2])\z/)
    Date.strptime(value, "%Y-%m")
  rescue ArgumentError
    @today.beginning_of_month
  end
end
