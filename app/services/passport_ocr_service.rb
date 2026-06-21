# app/services/passport_ocr_service.rb
require "net/http"
require "json"
require "base64"

class PassportOcrService
  def initialize(file_path)
    @file_path = file_path.to_s
  end

  def call
    return nil unless File.exist?(@file_path)

    access_token = ENV["GOOGLE_CLOUD_ACCESS_TOKEN"] || `gcloud auth application-default print-access-token`.strip
    return nil if access_token.empty?

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

    return nil unless response.code == "200"

    json_body = JSON.parse(response.body)
    full_text = json_body.dig("responses", 0, "textAnnotations", 0, "description")

    if full_text
      mrz_lines = extract_mrz_lines(full_text)
      mrz_lines.size == 2 ? decode_mrz(mrz_lines) : nil
    else
      nil
    end
  end

  private

  def extract_mrz_lines(text)
    mrz_pattern = /[A-Z0-9<]{44}/i
    lines = text.split("\n")
    mrz_lines = lines.select { |line| line.gsub(/\s+/, "").match?(mrz_pattern) }
    mrz_lines.map { |line| line.gsub(/\s+/, "").upcase }
  end

  # Strictly parses the standard TD3 Format (International Passports)
  def decode_mrz(lines)
    line1 = lines[0]
    line2 = lines[1]

    # Line 1 Breakdown
    issuing_state = line1[2..4].tr("<", "")

    # Names are separated by << (Primary vs Secondary identifiers)
    name_part = line1[5..43]
    primary_id, secondary_id = name_part.split("<<")
    last_name = primary_id&.gsub("<", " ")&.strip
    first_names = secondary_id&.gsub("<", " ")&.strip

    # Line 2 Breakdown
    doc_number = line2[0..8].tr("<", "")
    nationality = line2[10..12].tr("<", "")

    raw_dob = line2[13..18]   # YYMMDD
    raw_sex = line2[20]       # M / F / X
    raw_expiry = line2[21..26] # YYMMDD

    {
      raw_mrz: lines,
      first_names: first_names,
      last_name: last_name,
      document_number: doc_number,
      nationality: nationality,
      issuing_state: issuing_state,
      sex: parse_sex(raw_sex),
      birthdate: format_mrz_date(raw_dob, birthdate: true),
      expiry_date: format_mrz_date(raw_expiry)
    }
  end

  def parse_sex(char)
    case char
    when "M" then "Male"
    when "F" then "Female"
    else "Other/Unspecified"
    end
  end

  def format_mrz_date(str, birthdate: false)
    return "Unknown" unless str&.match?(/\d{6}/)

    yy = str[0..1].to_i
    mm = str[2..3]
    dd = str[4..5]

    # Smooth century threshold calculation
    current_year = 2026
    current_yy = current_year % 100

    century = if birthdate
                yy > current_yy ? "19" : "20"
              else
                yy <= (current_yy + 50) ? "20" : "19"
              end

    "#{century}#{yy}-#{mm}-#{dd}"
  end
end
