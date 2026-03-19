module PlatformHelper
  WEEKDAY_LABELS = %w[Dom Seg Ter Qua Qui Sex Sab].freeze
  PLAYGROUND_ACTIVITIES = [
    {
      slug: "leitura",
      title: "Playground de leitura",
      badge: "Disponível",
      description: "Leia notas geradas automaticamente em diferentes claves, com pauta visual e quatro alternativas por rodada.",
      icon: "book-open-text",
      available: true
    },
    {
      slug: "ritmica",
      title: "Playground de rítmica",
      badge: "Em breve",
      description: "Pulso, subdivisão, síncopa e precisão de tempo com padrões gerados automaticamente.",
      icon: "drum",
      available: false
    },
    {
      slug: "percepcao",
      title: "Playground de percepção",
      badge: "Disponível",
      description: "Ouça intervalos melódicos gerados na hora e identifique a resposta correta entre quatro opções.",
      icon: "headphones",
      available: true
    },
    {
      slug: "harmonia",
      title: "Playground de harmonia",
      badge: "Disponível",
      description: "Ouça tríades, tétrades e progressões em bloco ou nota por nota, com perguntas geradas automaticamente.",
      icon: "music",
      available: true
    }
  ].freeze

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

  def playground_activity_catalog
    PLAYGROUND_ACTIVITIES
  end

  def playground_activity_for(slug)
    PLAYGROUND_ACTIVITIES.find { |activity| activity[:slug] == slug.to_s }
  end

  def instrument_option_icon(instrument_id)
    icon_asset = {
      "piano" => "instruments/piano_.png",
      "flute" => "instruments/flute_8939281.png",
      "clarinet" => "instruments/clarinet_3581863.png",
      "guitar" => "instruments/guitar_6777540.png",
      "organ" => "instruments/organ.png"
    }[instrument_id.to_s]

    if icon_asset.present?
      return image_tag(icon_asset, alt: "", class: "playground-select-card__icon-image")
    end

    svg_markup = case instrument_id.to_s
                 when "piano"
                   <<~SVG
                     <svg viewBox="0 0 64 64" aria-hidden="true">
                       <rect x="10" y="16" width="44" height="32" rx="8" fill="none" stroke="currentColor" stroke-width="3"/>
                       <path d="M18 24h28" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                       <path d="M18 24v18M25 24v18M32 24v18M39 24v18M46 24v18" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>
                       <path d="M22 24v10M29 24v10M36 24v10M43 24v10" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"/>
                     </svg>
                   SVG
                 when "flute"
                   <<~SVG
                     <svg viewBox="0 0 64 64" aria-hidden="true">
                       <path d="M12 34h33l9-9" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
                       <path d="M18 34v-5M25 34v-6M32 34v-6M39 34v-6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>
                       <circle cx="49" cy="25" r="1.8" fill="currentColor"/>
                       <path d="M51 23h3" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                     </svg>
                   SVG
                 when "clarinet"
                   <<~SVG
                     <svg viewBox="0 0 64 64" aria-hidden="true">
                       <path d="M22 14 41 46" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"/>
                       <path d="M19.5 18.5 38.5 50.5" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" opacity="0.35"/>
                       <circle cx="26.5" cy="22" r="2.1" fill="currentColor"/>
                       <circle cx="30.5" cy="29" r="2.1" fill="currentColor"/>
                       <circle cx="34.5" cy="36" r="2.1" fill="currentColor"/>
                       <path d="M40 45.5 47.5 43" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"/>
                       <path d="M20 14h5" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"/>
                     </svg>
                   SVG
                 when "guitar"
                   <<~SVG
                     <svg viewBox="0 0 64 64" aria-hidden="true">
                       <path d="M39 15.5 49 25.5" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                       <path d="M27 26 39 23.5" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                       <path d="M24 27.5c-6.1 1.7-10 7.1-10 12.7 0 6.1 5 11.1 11.1 11.1 4.5 0 8.5-2.4 10.7-6.3 3.1 2.8 7.5 3.4 11.3 1.1 4.7-2.9 6.1-9.1 3.2-13.8-2.8-4.6-8.8-6.3-13.5-3.9-2.5-1.8-5.5-2-8.8-0.9Z" fill="none" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/>
                       <circle cx="31" cy="37.5" r="3.1" fill="none" stroke="currentColor" stroke-width="2.7"/>
                       <path d="M44 20.5 47.8 16.7" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>
                     </svg>
                   SVG
                 else
                   <<~SVG
                     <svg viewBox="0 0 64 64" aria-hidden="true">
                       <path d="M18 48V28h28v20" fill="none" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/>
                       <path d="M22 28v-9M30 28V14M38 28v-12M46 28v-7" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                       <path d="M23 34h18" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
                       <path d="M23 34v10M29 34v10M35 34v10M41 34v10" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>
                     </svg>
                   SVG
                 end

    svg_markup.html_safe
  end

  def reading_note_staff_svg(exercise)
    ReadingStaffSvgRenderer.new(exercise:).call.html_safe
  end

  def interface_symbol_icon(name)
    svg_markup = case name.to_s
                 when "check"
                   <<~SVG
                     <svg viewBox="0 0 20 20" aria-hidden="true">
                       <path d="m5 10.4 3.1 3.1L15 6.7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                     </svg>
                   SVG
                 when "play"
                   <<~SVG
                     <svg viewBox="0 0 20 20" aria-hidden="true">
                       <path d="M6 4.5v11l9-5.5Z" fill="currentColor"/>
                     </svg>
                   SVG
                 when "restart"
                   <<~SVG
                     <svg viewBox="0 0 20 20" aria-hidden="true">
                       <path d="M5.2 6.7V3.8L2.8 6.2l2.4 2.4V5.7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                       <path d="M5.7 6.1a5.8 5.8 0 1 1-1.1 7.1" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                     </svg>
                   SVG
                 else
                   <<~SVG
                     <svg viewBox="0 0 20 20" aria-hidden="true">
                       <path d="M4 10h10" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                       <path d="M10 5.5 14.5 10 10 14.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                     </svg>
                   SVG
                 end

    svg_markup.html_safe
  end
end
