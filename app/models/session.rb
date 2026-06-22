# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user

  # Automatically collect metadata when sessions are initialized
  before_create :assign_metadata

  private

  def assign_metadata
    # Uses Rails Current attributes or controller context hooks if available
    self.ip_address = Current.ip_address
    self.user_agent = Current.user_agent
  end
end
