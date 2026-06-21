require "google/cloud/vision"

class PassportOcrService
  def initialize(file_path)
    @file_path = file_path

    @client = Google::Cloud::Vision.image_annotator do |config|
      config.credentials = gcp_credentials if gcp_credentials.present?

      # 🚀 This passes arguments straight to the underlying gRPC sub-channel
      # to stop it from deadlocking on macOS background sockets
      config.channel_args = {
        "grpc.dns_min_time_between_resolutions_ms" => 10000,
        "grpc.max_connection_backoff_ms" => 1000
      }
    end
  end

  def call
    response = @client.text_detection(image: @file_path)
    full_text = response.responses.first&.text_annotations&.first&.description

    return nil if full_text.blank?

    parse_mrz(full_text)
  end

  private

  def gcp_credentials
    # In development, fallback to nil so it uses your local `gcloud` CLI auth automatically
    return nil if Rails.env.development?

    gcp_key = Rails.application.credentials.dig(:google, :gcp_key)
    JSON.parse(gcp_key) if gcp_key.present?
  end

  private

  def parse_mrz(text)
    # Added the 'i' flag at the end: /[A-Z0-9<]{44}/i
    mrz_pattern = /[A-Z0-9<]{44}/i

    lines = text.split("\n")
    mrz_lines = lines.select { |line| line.gsub(/\s+/, "").match?(mrz_pattern) }

    # Strip spaces and convert back to uppercase so the MRZ gem can parse it later
    mrz_lines.map { |line| line.gsub(/\s+/, "").upcase }
  end
end
