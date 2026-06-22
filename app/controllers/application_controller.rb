class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  # Run this before ANY controller action executes
  before_action :set_request_metadata
  helper_method :current_user

  private

  # Grab the metadata from the live request and put it in our global Current tray
  def set_request_metadata
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
  end

  def current_user
    @current_user ||= Session.find_by(id: cookies.signed[:session_id])&.user if cookies.signed[:session_id]
  end

  def require_authentication
    unless current_user
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Security Policy Violation: You must be authenticated via Google."
          render turbo_stream: turbo_stream.update("flash-messages", partial: "passports/flashes")
        end
        format.html { redirect_to root_path, alert: "Authentication required." }
      end
    end
  end
end
