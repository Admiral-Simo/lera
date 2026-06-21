# app/controllers/passports_controller.rb
class PassportsController < ApplicationController
  def new
    @mrz_lines = []
  end

  def create
    if params[:passport].present? && params[:passport][:image].present?
      uploaded_file = params[:passport][:image]
      @mrz_lines = PassportOcrService.new(uploaded_file.tempfile.path).call

      if @mrz_lines.any?
        flash.now[:notice] = "Passport scanned successfully!"
      else
        flash.now[:alert] = "Could not find any valid MRZ lines in that image."
      end
    else
      flash.now[:alert] = "Please select an image file first."
      @mrz_lines = []
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("results-output", partial: "results", locals: { mrz_lines: @mrz_lines }),
          # 🚀 FIX: Pass an inline block template to render flash partial styles cleanly
          turbo_stream.update("flash-messages", partial: "passports/flashes")
        ]
      end
      format.html { render :new }
    end
  end
end
