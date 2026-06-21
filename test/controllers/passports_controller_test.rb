require "test_helper"

class PassportsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get passports_new_url
    assert_response :success
  end

  test "should get create" do
    get passports_create_url
    assert_response :success
  end
end
