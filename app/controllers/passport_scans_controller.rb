class PassportScansController < ApplicationController
  def create
    @scan = PassportScan.new(scan_params)

    if @scan.save
      # Trigger the extraction
      mrz_data = @scan.extract_data

      render json: { success: true, data: mrz_data }, status: :created
    else
      render json: { errors: @scan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def scan_params
    params.require(:passport_scan).permit(:photo)
  end
end
