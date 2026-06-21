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

      # Ensure we successfully isolated required MRZ lines (2 for Passport/TD2, 3 for TD1 ID Cards)
      return nil unless [2, 3].include?(mrz_lines.size)

      begin
        # Pass the self-healed character strings to the parser gem
        result = MRZ.parse(mrz_lines)

        # 🚀 BULLETPROOF STRUCTURAL EXTRACTION FOR MOROCCAN ID CARDS
        doc_num = result.document_number
        if result.nationality == "MAR"
          # Find the identity line containing the country indicator code
          idmar_line = mrz_lines.find { |line| line.include?("MAR") && line.include?("<") }

          if idmar_line
            # Split by the separator bracket.
            # Part 0: "IDMAROPI4JV82", Part 1: "9I776494<<<<<<<<"
            parts = idmar_line.split("<")
            if parts[1].present?
              # Drop the first digit (the check digit '9') and strip any trailing arrow buffers
              raw_id = parts[1][1..-1].gsub("<", "")

              # Normalize common OCR typos (e.g., if 'I' was scanned as a '1')
              doc_num = raw_id.gsub(/^1/, "I") if raw_id.start_with?("1") || raw_id.start_with?("I")
            end
          end
        end

        {
          raw_mrz: mrz_lines,
          document_type: format_doc_type(mrz_lines.first),
          first_names: result.first_name,
          last_name: result.last_name,
          document_number: doc_num,
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
  def enhance_image_for_ocr(source_path)
    ImageProcessing::MiniMagick
      .source(source_path)
      .loader(page: 0)
      .colorspace("Gray")
      .negate
      .lat("25x25+10%")
      .negate
      .contrast_stretch("2%x98%")
      .call
  end

  # 🗜️ UNIVERSAL STRING EXTRACTION ENGINE
  def extract_mrz_lines(text)
    lines = text.split("\n")
    mrz_lines = []

    lines.each do |line|
      cleaned = line.gsub(/\s+/, "").upcase

      if cleaned.match?(/[A-Z0-9<]{25,}/) && (cleaned.include?("<<<") || cleaned.start_with?("P<", "I<", "C<", "A<") || cleaned.end_with?("<<"))
        mrz_lines << cleaned
      end
    end

    mrz_lines = mrz_lines.uniq

    target_size = mrz_lines.any? { |l| l.length <= 32 } ? 3 : 2
    selected_lines = mrz_lines.first(target_size)

    return [] unless selected_lines.size == target_size

    expected_length = selected_lines.first.length <= 32 ? 30 : (selected_lines.first.length <= 38 ? 36 : 44)

    selected_lines.map do |line|
      cleaned_line = line[0..(expected_length - 1)]
      if cleaned_line.length < expected_length
        cleaned_line.ljust(expected_length, "<")
      else
        cleaned_line
      end
    end
  end

  def format_doc_type(first_line)
    case first_line[0]
    when "P" then "Passport"
    when "I", "C", "A" then "ID Card"
    else "Identity Document"
    end
  end

  def format_sex(sex_symbol)
    case sex_symbol.to_s.upcase
    when "M", "MALE" then "Male"
    when "F", "FEMALE" then "Female"
    else "Other/Unspecified"
    end
  end
end
