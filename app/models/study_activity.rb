class StudyActivity < ApplicationRecord
  AREAS = [
    "leitura",
    "ritmica",
    "percepcao",
    "harmonia",
    "apreciacao",
    "historia"
  ].freeze

  belongs_to :user

  validates :area, presence: true, inclusion: { in: AREAS }
  validates :xp_earned, numericality: { greater_than_or_equal_to: 0 }
  validates :minutes_practiced, numericality: { greater_than_or_equal_to: 0 }
  validates :occurred_on, presence: true
end
