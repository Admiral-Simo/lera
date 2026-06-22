class OauthCallbacksController < ApplicationController
  # Skip authentication checks for the callback action itself
  skip_before_action :require_authentication, only: [:create], raise: false

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    if user.persisted?
      # Start a new session (Adapting to your existing Rails 8 sessions schema)
      session_record = user.sessions.create!
      cookies.signed.permanent[:session_id] = session_record.id

      redirect_to root_path, notice: "Successfully authenticated via Google!"
    else
      redirect_to new_session_path, alert: "Authentication failed. Please try again."
    end
  end

  def failure
    redirect_to new_session_path, alert: "Google Authentication failed: #{params[:message]}"
  end
end
