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

  test "nearby reminders are visible within 30 minutes after creation of a memo with location" do
    now = Time.zone.local(2026, 1, 7, 12, 0)
    memo = Memo.new(lonlat: "POINT(139.7671 35.6812)", created_at: now - 30.minutes)
    assert memo.nearby_reminders_visible?(now)
    memo.created_at = now - 31.minutes
    assert_not memo.nearby_reminders_visible?(now)
    memo = Memo.new(lonlat: nil, created_at: now)
    assert_not memo.nearby_reminders_visible?(now)
  end

  test "tags through memo_tags by name" do
    assert_equal [tags(:tag1), tags(:tag2), tags(:old)], memos(:one).tags.to_a
  end

  test "destroying a memo removes its memo_tags" do
    assert_difference("MemoTag.count", -3) do
      memos(:one).destroy!
    end
  end

  test "memo_tags reject duplicates" do
    memo_tag = MemoTag.new(memo: memos(:one), tag: tags(:tag1))
    assert_not memo_tag.valid?
    assert memo_tag.errors.of_kind?(:tag_id, :taken)
  end

  test "tags must belong to the same user" do
    memo = Memo.new(user: @user, create_from: "::1", tag_ids: [tags(:tag1).id, tags(:tag3_two).id])
    assert_not memo.valid?
    assert memo.errors.of_kind?(:tag_ids, :not_owned)
    assert_equal ["タグに他のユーザーのタグは使えません"], memo.errors.full_messages
    memo.tag_ids = [tags(:tag1).id]
    assert memo.valid?
  end

  test "tags_contains has the memos with all the given tags" do
    other = Memo.create!(user: @user, create_from: "::1", tag_ids: [tags(:tag1).id])
    assert_equal [memos(:one), other].sort_by(&:id), Memo.tags_contains(tags(:tag1).id).sort_by(&:id)
    assert_equal [memos(:one)], Memo.tags_contains(tags(:tag1).id, tags(:tag2).id).to_a
    assert_equal Memo.count, Memo.tags_contains("").count
  end
end
