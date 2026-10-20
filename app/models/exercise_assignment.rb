class ExerciseAssignment < ApplicationRecord
  RULES_VERSION = "integrity-2".freeze
  belongs_to :user
  has_many :exercise_attempts, dependent: :destroy
  has_one :study_activity, dependent: :destroy
  attr_readonly :public_id, :user_id, :area, :rules_version, :exercise_payload, :content_digest

  def self.issue!(user:, area:, exercise:)
    ExerciseIntegrityValidator.validate!(area, exercise)
    create!(user:, area:, public_id: SecureRandom.uuid, answer_token: SecureRandom.uuid,
            rules_version: RULES_VERSION, exercise_payload: exercise.deep_stringify_keys,
            content_digest: ExerciseIntegrityValidator.digest(area, exercise), expires_at: 12.hours.from_now)
  end

  def exercise
    exercise_payload.deep_symbolize_keys.merge(assignment_id: public_id, attempt_token: answer_token)
  end
end
