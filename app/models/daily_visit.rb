class DailyVisit < ApplicationRecord
  ZONE = "America/Sao_Paulo".freeze
  belongs_to :user
  validates :visited_on, presence: true

  def self.record_for(user, at: Time.current)
    insert_all([{ user_id: user.id, visited_on: at.in_time_zone(ZONE).to_date, created_at: at, updated_at: at }], unique_by: [:user_id, :visited_on])
  end
end
