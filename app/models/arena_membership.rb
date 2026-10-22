class ArenaMembership < ApplicationRecord
  belongs_to :arena_session
  belongs_to :user, optional: true
  validates :user, presence: true, on: :create
  validates :user_id, uniqueness: { scope: :arena_session_id }, if: -> { user_id.present? }
  validates :nickname, presence: true, length: { maximum: 40 }
  validates :status, inclusion: { in: %w[active left removed] }
  validates :avatar_id, inclusion: { in: Arena::Avatars::IDS }
  attr_readonly :arena_session_id, :user_id, :created_at, :avatar_id
end
