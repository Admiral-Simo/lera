# app/models/user.rb
class User < ApplicationRecord
  has_secure_password validations: false

  # This sets up the relationship mapping to your database table
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, if: -> { provider.blank? && password_digest.nil? }

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email_address = auth.info.email
    end
  end
end
