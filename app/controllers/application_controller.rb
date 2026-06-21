class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :current_user

  private

  def current_user
    @current_user ||= Session.find_by(id: cookies.signed[:session_id])&.user if cookies.signed[:session_id]
  end

  def require_authentication
    unless current_user
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Security Policy Violation: You must be authenticated via Google to execute OCR operations."
          render turbo_stream: turbo_stream.update("flash-messages", partial: "passports/flashes")
        end
        format.html { redirect_to root_path, alert: "Authentication required." }
      end
    end
  end
end
