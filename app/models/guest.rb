# app/models/guest.rb
class Guest < ApplicationRecord
  # Track hotel check-in status
  validates :status, inclusion: { in: %w[pending checked_in checked_out] }

  scope :active, -> { where(status: %w[pending checked_in]) }
end
