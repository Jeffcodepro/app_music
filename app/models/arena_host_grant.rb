class ArenaHostGrant < ApplicationRecord
  belongs_to :user, optional: true
  scope :active, -> { where(revoked_at: nil).where.not(user_id: nil) }
  validates :user, presence: true, on: :create
  validates :user_id, uniqueness: { conditions: -> { where(revoked_at: nil) } }, if: -> { revoked_at.nil? }
  validates :operator_reference, :granted_at, presence: true
  attr_readonly :user_id, :operator_reference, :granted_at, :created_at
end
