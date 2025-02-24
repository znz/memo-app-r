require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  def authorization = ActionController::HttpAuthentication::Basic.encode_credentials(ENV["STATS_BASIC_AUTH_USER"], ENV["STATS_BASIC_AUTH_PASS"])

  test "should get gc" do
    get stats_gc_url(format: :json), headers: { 'HTTP_AUTHORIZATION' => authorization }
    assert_response :success
  end

  test "should get yjit" do
    get stats_yjit_url(format: :json), headers: { 'HTTP_AUTHORIZATION' => authorization }
    assert_response :success
  end
end
