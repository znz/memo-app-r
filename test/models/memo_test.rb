# frozen_string_literal: true

require "test_helper"

class MemoTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.confirm
  end

  test "UUIDv4 to_param" do
    memo = Memo.create!(user: @user, create_from: "::1", id: SecureRandom.uuid_v4)
    assert_match(/\A\h{8}-\h{4}-4\h{3}-\h{4}-\h{12}\z/, memo.to_param)
    assert_equal memo, Memo.find_uuid(memo.id)
    assert_equal memo, Memo.find_uuid(memo.to_param)
  end

  test "UUIDv7 to_param" do
    memo = Memo.create!(user: @user, create_from: "::1")
    assert_match(/\A[#{Base58Uuid::BASE58_ALPHABET}]{22}\z/o, memo.to_param)
    assert_equal memo, Memo.find_uuid(memo.id)
    assert_equal memo, Memo.find_uuid(memo.to_param)
  end
end
