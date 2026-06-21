# app/services/passport_ocr_service.rb
require "net/http"
require "json"
require "base64"
require "mrz"                         # Battle-tested parsing gem
require "image_processing/mini_magick" # Image preprocessing engine

class PassportOcrService
  def initialize(file_path)
    @file_path = file_path.to_s
  end

  def call
    return nil unless File.exist?(@file_path)

    # 1. Preprocess the image to flatten ambient shadows and isolate text
    processed_file = enhance_image_for_ocr(@file_path)
    return nil if processed_file.nil?

    # 2. Authenticate using environment variable or local fallback
    access_token = ENV["GOOGLE_CLOUD_ACCESS_TOKEN"] || `gcloud auth application-default print-access-token`.strip
    return nil if access_token.empty?

    # 3. Read the ENHANCED image bytes instead of the shadow-heavy original file
    image_bytes = File.binread(processed_file.path)
    base64_image = Base64.strict_encode64(image_bytes)

    uri = URI("https://vision.googleapis.com/v1/images:annotate")
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

    # 4. Clean up the generated enhanced file from disk safely
    File.delete(processed_file.path) if File.exist?(processed_file.path)

    return nil unless response.code == "200"

    json_body = JSON.parse(response.body)
    full_text = json_body.dig("responses", 0, "textAnnotations", 0, "description")

    if full_text
      mrz_lines = extract_mrz_lines(full_text)

      # Ensure we successfully isolated both required MRZ lines
      return nil unless mrz_lines.size == 2

      begin
        # Pass the self-healed, 44-character strings to the parser gem
        result = MRZ.parse(mrz_lines)

        {
          raw_mrz: mrz_lines,
          first_names: result.first_name,
          last_name: result.last_name,
          document_number: result.document_number,
          nationality: result.nationality,
          issuing_state: result.issuing_state,
          sex: format_sex(result.sex),
          birthdate: result.birth_date.to_s,     # Clean standard format: "YYYY-MM-DD"
          expiry_date: result.expiration_date.to_s,
          valid_checksums?: result.valid?        # Global safety checksum pass/fail
        }
      rescue MRZ::InvalidFormatError
        nil
      end
    else
      nil
    end
  end

  private

  # 🛠️ ALGORITHMIC PRE-PROCESSING LAYER
  # Converts the image to grayscale and applies an Adaptive Threshold matrix.
  # This destroys shadow lines locally, rendering text crisp black on pure white backgrounds.
  def enhance_image_for_ocr(source_path)
    ImageProcessing::MiniMagick
      .source(source_path)
      .loader(page: 0)
      .colorspace("Gray")
      .negate
      .lat("25x25+10%") # Local Adaptive Threshold (clears shadows within a localized window)
      .negate
      .contrast_stretch("2%x98%")
      .call # Returns a natively managed File object mapping cleanly to .path
  end

  # 🗜️ STRING EXTRACTION & TRUNCATION SELF-HEALING ENGINE
  def extract_mrz_lines(text)
    lines = text.split("\n")
    mrz_lines = []

    lines.each do |line|
      cleaned = line.gsub(/\s+/, "").upcase

      # Target Line 1 (starts with P<) or Line 2 (contains concentrated passport padding blocks)
      if cleaned.start_with?("P<") || (cleaned.match?(/[A-Z0-9<]{25,}/) && cleaned.include?("<<<"))
        mrz_lines << cleaned
      end
    end

    # Isolate top 2 distinct candidate lines
    mrz_lines = mrz_lines.uniq.first(2)
    return [] unless mrz_lines.size == 2

    mrz_lines.map do |line|
      if line.length < 44
        # Self-Heal: Pad out truncated text to the precise 44-character ICAO standard
        line.ljust(44, "<")
      else
        line[0..43]
      end
    end
  end

  def format_sex(sex_symbol)
    case sex_symbol
    when :male then "Male"
    when :female then "Female"
    else "Other/Unspecified"
    end
  end
end
