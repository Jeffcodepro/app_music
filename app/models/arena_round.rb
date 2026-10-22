class ArenaRound < ApplicationRecord
  TRANSITIONS = {
    "queued" => %w[preparing void], "preparing" => %w[ready paused void],
    "ready" => %w[answering paused void], "answering" => %w[closed paused void],
    "paused" => %w[preparing ready answering closed void], "closed" => %w[results], "results" => [], "void" => []
  }.freeze
  belongs_to :arena_session
  belongs_to :arena_question_snapshot
  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :arena_session_id }
  validates :state, inclusion: { in: TRANSITIONS.keys }
  validate :same_session
  validate :valid_transition, on: :update
  attr_readonly :arena_session_id, :arena_question_snapshot_id, :position, :created_at

  def as_json(*) = raise(Arena::PrivatePayload, "Use an explicit audience projection")
  def serializable_hash(*) = raise(Arena::PrivatePayload, "Use an explicit audience projection")

  private

  def same_session
    if arena_question_snapshot && arena_question_snapshot.arena_session_id != arena_session_id
      errors.add(:arena_question_snapshot, "não pertence à sessão")
    end
  end

  def valid_transition
    return unless will_save_change_to_state?
    allowed = TRANSITIONS.fetch(state_in_database, []).include?(state)
    allowed &&= state == "void" || state == paused_from_in_database || (state == "closed" && paused_from_in_database == "answering") if state_in_database == "paused"
    errors.add(:state, "transição inválida") unless allowed
  end
end
