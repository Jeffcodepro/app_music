class ArenaEvent < ApplicationRecord
  KINDS = %w[session_created session_state_changed round_state_changed answer_recorded account_removed].freeze
  belongs_to :arena_session
  belongs_to :arena_round, optional: true
  belongs_to :actor, class_name: "User", optional: true
  validates :kind, inclusion: { in: KINDS }
  validates :sequence, numericality: { only_integer: true, greater_than: 0 }
  validate :safe_payload
  attr_readonly :arena_session_id, :arena_round_id, :actor_id, :sequence, :session_version, :kind, :payload, :created_at

  def as_json(*) = raise(Arena::PrivatePayload, "Events need an authorized audience projection")
  def serializable_hash(*) = raise(Arena::PrivatePayload, "Events need an authorized audience projection")

  private

  def safe_payload
    valid = if kind == "answer_recorded"
      payload.is_a?(Hash) && payload.keys == ["membership_id"] && payload["membership_id"].is_a?(String) && payload["membership_id"].match?(/\A[0-9a-f-]{36}\z/)
    else
      states = case kind
      when "session_created" then ["draft"]
      when "session_state_changed", "account_removed" then ArenaSession::TRANSITIONS.keys
      when "round_state_changed" then ArenaRound::TRANSITIONS.keys
      else []
      end
      payload.is_a?(Hash) && payload.keys == ["state"] && states.include?(payload["state"])
    end
    errors.add(:payload, "evento não permitido") unless valid
  end
end
