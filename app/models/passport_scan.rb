# app/models/passport_scan.rb
class PassportScan < ApplicationRecord
  has_one_attached :photo

  def extract_data
    return nil unless photo.attached?

    # Open the Active Storage file and hand its local path to your Service
    photo.open do |local_file|
      PassportOcrService.new(local_file.path).call
    end
  end
end
