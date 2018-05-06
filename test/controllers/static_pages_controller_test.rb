# frozen_string_literal: true

require 'test_helper'

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = users(:one)
    user.confirm
    sign_in user
  end

  test 'should get home' do
    get root_url
    assert_response :success
  end

  test 'should get about' do
    get about_url
    assert_response :success
  end
end
