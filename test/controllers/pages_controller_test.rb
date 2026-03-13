require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get guide" do
    get pages_guide_url
    assert_response :success
  end
end
