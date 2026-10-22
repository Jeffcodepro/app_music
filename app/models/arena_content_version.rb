class ArenaContentVersion < ApplicationRecord
  validates :code, :title, :content_digest, :source_digest, presence: true
  validates :revision, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :code }
  validates :status, inclusion: { in: %w[draft technical_preview published archived] }
  scope :published, -> { where(status: "published") }
  def published? = status == "published"
  def as_json(*) = raise(Arena::PrivatePayload, "Content requires an audience projection")
  def serializable_hash(*) = raise(Arena::PrivatePayload, "Content requires an audience projection")
end
