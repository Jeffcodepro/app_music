class ArenaSession < ApplicationRecord
  TRANSITIONS = {
    "draft" => %w[lobby_open cancelled], "lobby_open" => %w[lobby_locked expired cancelled],
    "lobby_locked" => %w[lobby_open live cancelled], "live" => %w[paused interrupted completed cancelled],
    "paused" => %w[live interrupted completed cancelled], "interrupted" => %w[live paused cancelled],
    "completed" => [], "cancelled" => [], "expired" => []
  }.freeze
  TERMINAL = %w[completed cancelled expired].freeze
  IN_PROGRESS = %w[lobby_locked live paused interrupted].freeze

  belongs_to :host, class_name: "User", optional: true
  belongs_to :arena_content_version, optional: true
  belongs_to :rematch_session, class_name: "ArenaSession", optional: true
  has_many :arena_memberships
  has_many :arena_rounds
  has_many :arena_question_snapshots
  has_many :arena_answers
  has_many :arena_events
  validates :host, presence: true, on: :create
  validates :title, presence: true, length: { maximum: 120 }
  validates :state, inclusion: { in: TRANSITIONS.keys }
  validates :visibility, inclusion: { in: %w[private public] }
  validates :scoring_version, inclusion: { in: Arena::Scoring::VERSIONS }
  validates :capacity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 40 }
  validates :presentation_mode, inclusion: { in: %w[legacy individual presenter] }
  validates :experience, inclusion: { in: %w[facilitated party] }
  validates :listening_policy, inclusion: { in: %w[manual-v1 sequence-v1] }
  validates :listening_repetitions, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 5 }
  validate :valid_transition, on: :update
  before_validation :set_terminal_time
  attr_readonly :host_id, :created_at, :experience, :visibility, :capacity, :scoring_version, :presentation_mode, :listening_policy, :listening_repetitions

  def party? = experience == "party"
  def host_ready? = !party? || arena_memberships.exists?(user_id: host_id, status: "active")

  private

  def set_terminal_time
    self.ended_at ||= Time.current if TERMINAL.include?(state)
    self.resume_from = state_in_database if will_save_change_to_state? && state == "interrupted"
  end

  def valid_transition
    return unless will_save_change_to_state?
    allowed = TRANSITIONS.fetch(state_in_database, []).include?(state)
    allowed &&= state == "cancelled" || state == resume_from_in_database if state_in_database == "interrupted"
    errors.add(:state, "transição inválida") unless allowed
  end
end
