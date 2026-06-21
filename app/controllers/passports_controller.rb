# app/controllers/passports_controller.rb
class PassportsController < ApplicationController
  def new
    @passport_data = nil
  end

  def create
    if params[:passport].present? && params[:passport][:image].present?
      uploaded_file = params[:passport][:image]

      # Now returns the fully parsed metadata payload hash
      @passport_data = PassportOcrService.new(uploaded_file.tempfile.path).call

      if @passport_data
        flash.now[:notice] = "Passport details extracted successfully!"
      else
        flash.now[:alert] = "Could not find or parse standard Passport MRZ fields."
      end
    else
      flash.now[:alert] = "Please select an image file first."
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("results-output", partial: "results", locals: { passport_data: @passport_data }),
          turbo_stream.update("flash-messages", partial: "passports/flashes")
        ]
      end
      format.html { render :new }
    end
  end
end
