# app/services/passport_ocr_service.rb
require "net/http"
require "json"
require "base64"

class PassportOcrService
  def initialize(file_path)
    @file_path = file_path.to_s
  end

  def call
    return [] unless File.exist?(@file_path)

    # In production, use your environment credentials. In local dev, fallback to gcloud CLI token.
    access_token = ENV["GOOGLE_CLOUD_ACCESS_TOKEN"] || `gcloud auth application-default print-access-token`.strip
    return [] if access_token.empty?

    uri = URI("https://vision.googleapis.com/v1/images:annotate")
    image_bytes = File.binread(@file_path)
    base64_image = Base64.strict_encode64(image_bytes)

    payload = {
      requests: [{
        image: { content: base64_image },
        features: [{ type: "TEXT_DETECTION" }]
      }]
    }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request["X-Goog-User-Project"] = "passportscanner98123"
      request.body = payload
      http.request(request)
    end

    return [] unless response.code == "200"

    json_body = JSON.parse(response.body)
    full_text = json_body.dig("responses", 0, "textAnnotations", 0, "description")

    full_text ? parse_mrz(full_text) : []
  end

  private

  def parse_mrz(text)
    mrz_pattern = /[A-Z0-9<]{44}/i
    lines = text.split("\n")
    mrz_lines = lines.select { |line| line.gsub(/\s+/, "").match?(mrz_pattern) }
    mrz_lines.map { |line| line.gsub(/\s+/, "").upcase }
  end
end
