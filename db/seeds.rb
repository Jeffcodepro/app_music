# frozen_string_literal: true

puts "Seeding users for development..."

users = [
  {
    email: "dev.free@appmusic.com",
    full_name: "Dev Primeira Nota",
    phone: "(11) 90000-0001",
    plan: "Primeira Nota"
  },
  {
    email: "dev.harmonia@appmusic.com",
    full_name: "Dev Harmonia",
    phone: "(11) 90000-0002",
    plan: "Harmonia"
  },
  {
    email: "dev.maestro@appmusic.com",
    full_name: "Dev Maestro",
    phone: "(11) 90000-0003",
    plan: "Maestro"
  }
]

seeded_users = users.map do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(
    full_name: attrs[:full_name],
    phone: attrs[:phone],
    plan: attrs[:plan],
    password: "123456",
    password_confirmation: "123456"
  )
  user.save!
  user
end

# Usuário sem plano para testar o onboarding de escolha de plano.
onboarding_user = User.find_or_initialize_by(email: "dev.onboarding@appmusic.com")
onboarding_user.assign_attributes(
  full_name: "Dev Onboarding",
  phone: "(11) 90000-0099",
  plan: nil,
  password: "123456",
  password_confirmation: "123456"
)
onboarding_user.save!

def seed_study_activities(user, streak_days:, extra_days:, xp_range:, minutes_range:)
  user.study_activities.delete_all
  areas = StudyActivity::AREAS

  # Garante streak ativo até o dia de hoje.
  streak_days.times do |offset|
    day = Date.current - offset
    rand(1..2).times do
      user.study_activities.create!(
        area: areas.sample,
        xp_earned: rand(xp_range),
        minutes_practiced: rand(minutes_range),
        occurred_on: day
      )
    end
  end

  # Simula histórico mais antigo e variado.
  random_offsets = ((streak_days + 1)..45).to_a.sample(extra_days)
  random_offsets.each do |offset|
    day = Date.current - offset
    rand(1..2).times do
      user.study_activities.create!(
        area: areas.sample,
        xp_earned: rand(xp_range),
        minutes_practiced: rand(minutes_range),
        occurred_on: day
      )
    end
  end
end

seeded_users.each do |user|
  case user.plan&.downcase
  when "maestro"
    seed_study_activities(user, streak_days: 16, extra_days: 18, xp_range: 30..85, minutes_range: 25..70)
  when "harmonia"
    seed_study_activities(user, streak_days: 10, extra_days: 14, xp_range: 20..60, minutes_range: 20..55)
  else
    seed_study_activities(user, streak_days: 6, extra_days: 10, xp_range: 10..40, minutes_range: 10..35)
  end
end

puts "Done."
puts "Login padrão: dev.free@appmusic.com / 123456"
