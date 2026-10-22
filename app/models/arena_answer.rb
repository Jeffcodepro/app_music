class ArenaAnswer < ApplicationRecord
  belongs_to :arena_session
  belongs_to :arena_round
  belongs_to :arena_membership
  validates :option_id, :idempotency_key, :accepted_at, presence: true
  attr_readonly :arena_session_id, :arena_round_id, :arena_membership_id, :option_id, :idempotency_key, :accepted_at, :response_elapsed_ms, :created_at

  def as_json(*) = raise(Arena::PrivatePayload, "Use a private answer acknowledgement")
  def serializable_hash(*) = raise(Arena::PrivatePayload, "Use a private answer acknowledgement")
end
