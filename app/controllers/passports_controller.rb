# app/controllers/passports_controller.rb
class PassportsController < ApplicationController
  def new
    @guests = Guest.active.order(created_at: :desc)
  end

  def create
    if params[:passport].present? && params[:passport][:image].present?
      uploaded_file = params[:passport][:image]
      passport_data = PassportOcrService.new(uploaded_file.tempfile.path).call

      if passport_data
        # Create a new guest profile directly from the extracted OCR data
        @guest = Guest.create!(
          first_names: passport_data[:first_names],
          last_name: passport_data[:last_name],
          document_number: passport_data[:document_number],
          sex: passport_data[:sex],
          birthdate: passport_data[:birthdate],
          expiry_date: passport_data[:expiry_date],
          nationality: passport_data[:nationality],
          issuing_state: passport_data[:issuing_state],
          status: "pending"
        )
        flash.now[:notice] = "Guest identity verified! Profile created below."
      else
        flash.now[:alert] = "Could not parse standard Passport MRZ fields."
      end
    else
      flash.now[:alert] = "Please select an image file first."
    end

    @guests = Guest.active.order(created_at: :desc)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("dashboard-grid", partial: "dashboard_grid", locals: { guests: @guests }),
          turbo_stream.update("flash-messages", partial: "passports/flashes")
        ]
      end
      format.html { redirect_to passports_path }
    end
  end

  # Quick action for front desk to assign a room and complete check-in
  def update
    @guest = Guest.find(params[:id])
    if @guest.update(room_number: params[:room_number], status: "checked_in", checked_in_at: Time.current)
      flash.now[:notice] = "Guest assigned to Room #{params[:room_number]} successfully!"
    end

    @guests = Guest.active.order(created_at: :desc)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("dashboard-grid", partial: "dashboard_grid", locals: { guests: @guests }),
          turbo_stream.update("flash-messages", partial: "passports/flashes")
        ]
      end
    end
  end
end
