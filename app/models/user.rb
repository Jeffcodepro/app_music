class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2 apple]

  validates :full_name, presence: true, on: :create
  has_many :study_activities, dependent: :destroy
  has_one_attached :avatar

  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize
    user.email = auth.info.email
    user.full_name = auth.info.name.presence || auth.info.email.split("@").first
    user.password = Devise.friendly_token[0, 20] if user.encrypted_password.blank?
    user.save!
    user
  end
end
