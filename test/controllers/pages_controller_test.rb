# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = users(:one)
    user.confirm
    sign_in user
  end

  test "should get about" do
    get about_url
    assert_response :success
  end
end
