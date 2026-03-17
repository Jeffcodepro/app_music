module PlatformHelper
  WEEKDAY_LABELS = %w[Dom Seg Ter Qua Qui Sex Sab].freeze

  def platform_streak_days(user)
    return 0 unless user

    days = user.study_activities.distinct.order(occurred_on: :desc).pluck(:occurred_on)
    return 0 if days.empty?

    day_set = days.index_with { true }
    streak = 0
    cursor = Date.current

    while day_set[cursor]
      streak += 1
      cursor -= 1.day
    end

    streak
  end

  def platform_streak_dates(user)
    return [] unless user

    days = user.study_activities.distinct.order(occurred_on: :desc).pluck(:occurred_on)
    return [] if days.empty?

    day_set = days.index_with { true }
    streak_dates = []
    cursor = Date.current

    while day_set[cursor]
      streak_dates << cursor
      cursor -= 1.day
    end

    streak_dates
  end

  def platform_activity_day_map(user, month = Date.current)
    return {} unless user

    user.study_activities
      .where(occurred_on: month.beginning_of_month..month.end_of_month)
      .distinct
      .pluck(:occurred_on)
      .index_with { true }
  end

  def platform_calendar_weeks(month = Date.current)
    first = month.beginning_of_month.beginning_of_week(:sunday)
    last = month.end_of_month.end_of_week(:sunday)
    (first..last).to_a.each_slice(7).to_a
  end

  def platform_xp_total(user)
    return 0 unless user

    user.study_activities.sum(:xp_earned)
  end

  def platform_practice_minutes(user)
    return 0 unless user

    user.study_activities.sum(:minutes_practiced)
  end

  def platform_activity_days_count(user)
    return 0 unless user

    user.study_activities.distinct.count(:occurred_on)
  end

  def user_initials(user)
    seed = user&.full_name.presence || user&.email.to_s
    return "AM" if seed.blank?

    seed.split.first(2).map { |part| part[0].upcase }.join
  end

  def user_avatar(user, css_class: "app-avatar")
    if user&.avatar&.attached?
      image_tag(user.avatar, class: css_class, alt: "Foto de perfil")
    else
      content_tag(:span, user_initials(user), class: css_class)
    end
  end
end
