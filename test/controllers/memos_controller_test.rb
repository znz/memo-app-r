# frozen_string_literal: true

require "test_helper"

class MemosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = users(:one)
    user.confirm
    sign_in user
    @memo = memos(:one)
  end

  test "should get index" do
    get memos_url
    assert_response :success
  end

  test "should get index with q" do
    get memos_url(q: { content_cont: "test" })
    assert_response :success
  end

  test "should get new" do
    get new_memo_url
    assert_response :success
  end

  test "should create memo" do
    assert_difference("Memo.count") do
      post memos_url, params: { memo: { content: @memo.content, create_from: @memo.create_from, info: @memo.info, price: @memo.price, tags: @memo.tags, user_id: @memo.user_id } }
    end

    assert_redirected_to memo_url(Memo.order(:created_at).last)
  end

  test "should show memo" do
    get memo_url(@memo)
    assert_response :success
  end

  test "should get edit" do
    get edit_memo_url(@memo)
    assert_response :success
  end

  test "should update memo" do
    patch memo_url(@memo), params: { memo: { content: @memo.content, price: @memo.price, tags: @memo.tags } }
    assert_redirected_to memo_url(@memo)
  end

  test "should destroy memo" do
    assert_difference("Memo.count", -1) do
      delete memo_url(@memo)
    end

    assert_redirected_to memos_url
  end
end
