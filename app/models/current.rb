# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  # Define variables that can be accessed globally during a request
  attribute :ip_address, :user_agent
end
