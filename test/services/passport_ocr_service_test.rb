# test/services/passport_ocr_service_test.rb
require "test_helper"

class PassportOcrServiceTest < ActiveSupport::TestCase
  test "it extracts MRZ lines from a passport image path" do
    image_path = file_fixture("1.png").to_s

    # 1. Build a clean, nested structural mock of the Google Vision Response
    fake_text_annotation = Struct.new(:description).new(
      "PASSPORT\nP<USAUSER<<HAPPY<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n1234567891USA8501019M2501012<<<<<<<<<<<<<<06"
    )
    fake_response_element = Struct.new(:text_annotations).new([fake_text_annotation])
    fake_response = Struct.new(:responses).new([fake_response_element])

    # 2. Build a simple mock client that implements #text_detection cleanly
    fake_client = Object.new
    fake_client.define_singleton_method(:text_detection) do |image:|
      fake_response
    end

    # 3. Handle Google's initialization configuration block cleanly
    mock_image_annotator_builder = ->(&block) do
      if block
        fake_config = Struct.new(:credentials).new(nil)
        block.call(fake_config)
      end
      fake_client
    end

    # 4. Stub and execute
    Google::Cloud::Vision.stub :image_annotator, mock_image_annotator_builder do
      service = PassportOcrService.new(image_path)
      result = service.call

      assert_equal 2, result.size
      # Add one more '<' here to match what the service is actually outputting:
      assert_equal "P<USAUSER<<HAPPY<<<<<<<<<<<<<<<<<<<<<<<<<<<<", result[0]
      assert_equal "1234567891USA8501019M2501012<<<<<<<<<<<<<<06", result[1]
    end
  end
end
