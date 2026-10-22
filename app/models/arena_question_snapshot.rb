class ArenaQuestionSnapshot < ApplicationRecord
  belongs_to :arena_session
  belongs_to :arena_content_version, optional: true
  before_validation :derive_digest, on: :create
  validate :valid_choice_contract
  validates :payload_version, inclusion: { in: %w[choice-v1 reading-note-v1 reading-visual-v2 music-choice-v3] }
  attr_readonly :arena_session_id, :payload, :payload_version, :payload_digest, :created_at

  def option_ids = payload.fetch("options").map { |option| option.fetch("id") }
  def as_json(*) = raise(Arena::PrivatePayload, "Use an explicit audience projection")
  def serializable_hash(*) = raise(Arena::PrivatePayload, "Use an explicit audience projection")

  private

  def derive_digest
    self.payload_digest = Digest::SHA256.hexdigest(JSON.generate(canonical(payload)))
  end

  def canonical(value)
    case value
    when Hash then value.sort.to_h.transform_values { |nested| canonical(nested) }
    when Array then value.map { |nested| canonical(nested) }
    else value
    end
  end

  def valid_choice_contract
    value = payload
    if payload_version == Arena::MusicContent::TYPE
      begin
        Arena::MusicContent.validate_snapshot!(value, content_version_id: arena_content_version_id)
        raise Arena::InvalidContent unless arena_content_version && value["source_status"] == arena_content_version.status && arena_content_version.body.fetch("exercises").include?(value.fetch("entry"))
      rescue Arena::InvalidContent
        errors.add(:payload, "conteúdo musical inconsistente")
      end
      return
    end
    if %w[reading-note-v1 reading-visual-v2].include?(payload_version)
      begin
        adapter = payload_version == "reading-visual-v2" ? Arena::ReadingVisualContent : Arena::ReadingContent
        adapter.validate_snapshot!(value, content_version_id: arena_content_version_id)
        unless arena_content_version && value["source_status"] == arena_content_version.status && arena_content_version.body.fetch("exercises").include?(value.fetch("exercise"))
          raise Arena::InvalidContent, "Exercise differs from frozen source"
        end
        if payload_version == "reading-visual-v2" && value["profile"] != arena_content_version.body["profile"]
          raise Arena::InvalidContent, "Snapshot profile differs from source"
        end
      rescue Arena::InvalidContent
        errors.add(:payload, "conteúdo musical inconsistente")
      end
      return
    end
    valid = value.is_a?(Hash) && value.keys.sort == %w[correct_option_id options prompt] &&
      value["prompt"].is_a?(String) && value["prompt"].strip.length.between?(1, 500) &&
      value["options"].is_a?(Array) && value["options"].size == 4
    if valid
      valid = value["options"].all? do |option|
        option.is_a?(Hash) && option.keys.sort == %w[id label] && option["id"].is_a?(String) &&
          option["id"].match?(/\A[A-Za-z0-9_-]{1,80}\z/) && option["label"].is_a?(String) && option["label"].strip.length.between?(1, 200)
      end
    end
    if valid
      ids = value["options"].map { |option| option["id"] }
      labels = value["options"].map { |option| option["label"].strip.unicode_normalize.downcase }
      valid = ids.uniq.size == 4 && labels.uniq.size == 4 && ids.include?(value["correct_option_id"])
    end
    errors.add(:payload, "contrato de quatro alternativas inválido") unless valid
  end
end
