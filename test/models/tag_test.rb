# frozen_string_literal: true

require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "requires user" do
    tag = Tag.new(name: "仕事")
    assert_not tag.valid?
    assert tag.errors.of_kind?(:user, :blank)
  end

  test "requires name" do
    tag = Tag.new(user: users(:one), name: "")
    assert_not tag.valid?
    assert tag.errors.of_kind?(:name, :blank)
  end

  test "name is unique within the same user" do
    tag = Tag.new(user: users(:one), name: tags(:work).name)
    assert_not tag.valid?
    assert tag.errors.of_kind?(:name, :taken)
  end

  test "same name is allowed for another user" do
    tag = Tag.new(user: users(:two), name: tags(:work).name, memo_use: "enabled")
    assert tag.valid?
  end

  test "defaults" do
    tag = Tag.new
    assert_equal %w[unused unused], [tag.memo_use, tag.reminder_use]
    assert_equal "secondary", tag.color
  end

  test "uses have predicates" do
    assert tags(:work).memo_enabled?
    assert tags(:work).reminder_enabled?
    assert tags(:archived).reminder_disabled?
    assert tags(:medicine).reminder_unused?
  end

  test "uses must be one of the uses" do
    tag = Tag.new(user: users(:one), name: "新規", memo_use: "maybe", reminder_use: "enabled")
    assert_not tag.valid?
    assert tag.errors.of_kind?(:memo_use, :inclusion)
  end

  test "color must be a theme color" do
    tag = Tag.new(user: users(:one), name: "新規", color: "pink")
    assert_not tag.valid?
    assert tag.errors.of_kind?(:color, :inclusion)
  end

  test "every theme color is accepted" do
    ThemeColor::COLORS.each do |color|
      assert Tag.new(user: users(:one), name: "新規", color:, memo_use: "enabled").valid?, color
    end
  end

  test "a tag is used for memos or reminders" do
    tag = Tag.new(user: users(:one), name: "新規")
    assert_not tag.valid?
    assert tag.errors.of_kind?(:base, :no_use)
    assert_equal ["メモかリマインダーのどちらかで使うようにしてください"], tag.errors.full_messages

    tag.memo_use = "disabled"
    assert tag.valid?
  end

  test "reminder_use cannot become unused while reminders have the tag" do
    tag = tags(:work)
    assert_not tag.update(reminder_use: "unused")
    assert tag.errors.of_kind?(:reminder_use, :in_use)
    assert_equal ["リマインダーでの利用は1件のリマインダーに付いているので「使わない」にできません"], tag.errors.full_messages

    tag.reminder_tags.destroy_all
    assert tag.update(reminder_use: "unused")
  end

  test "memo_use cannot become unused while memos have the tag" do
    tag = tags(:tag1)
    tag.reminder_use = "enabled"
    assert_not tag.update(memo_use: "unused")
    assert tag.errors.of_kind?(:memo_use, :in_use)
    assert_equal ["メモでの利用は1件のメモかリマインダーに付いているので「使わない」にできません"], tag.errors.full_messages
  end

  test "memo_use cannot become unused while reminders add the tag to memos" do
    tag = tags(:medicine)
    tag.reminder_use = "enabled"
    assert_not tag.update(memo_use: "unused")
    assert_equal ["メモでの利用は1件のメモかリマインダーに付いているので「使わない」にできません"], tag.errors.full_messages

    tag.reminder_memo_tags.destroy_all
    assert tag.update(memo_use: "unused")
  end

  test "a tag on memos cannot be destroyed" do
    tag = tags(:tag1)
    assert_not tag.destroy
    assert_equal ["メモが存在しているので削除できません"], tag.errors.full_messages
    assert Tag.exists?(tag.id)
  end

  test "destroying a tag removes it from the memo tags of reminders" do
    assert_difference("ReminderMemoTag.count", -1) do
      tags(:medicine).destroy!
    end
  end

  test "name is stripped" do
    assert_equal "新規", Tag.new(name: " 新規\t").name
  end

  test "use scopes" do
    assert_includes Tag.reminder_enabled, tags(:work)
    assert_not_includes Tag.reminder_enabled, tags(:archived)
    assert_includes Tag.not_reminder_unused, tags(:archived)
    assert_not_includes Tag.not_reminder_unused, tags(:medicine)
    assert_includes Tag.memo_enabled, tags(:medicine)
  end

  test "with_counts has the numbers of the reminders and the memos and the time of the last memo" do
    memos(:one).update!(created_at: Time.zone.local(2026, 1, 5, 10, 0))
    Memo.create!(user: users(:one), create_from: "::1", tag_ids: [tags(:tag1).id], created_at: Time.zone.local(2026, 1, 6, 9, 0))
    relation = users(:one).tags.with_counts.order(:name)
    assert_equal users(:one).tags.count, relation.count(:all)
    tags = relation.index_by(&:name)
    assert_equal [1, 0, nil], tags[tags(:work).name].then { [it.reminders_count, it.memos_count, it.last_memo_at] }
    assert_equal [0, 2, Time.zone.local(2026, 1, 6, 9, 0)], tags[tags(:tag1).name].then { [it.reminders_count, it.memos_count, it.last_memo_at] }
    assert_equal [0, 1, Time.zone.local(2026, 1, 5, 10, 0)], tags[tags(:tag2).name].then { [it.reminders_count, it.memos_count, it.last_memo_at] }
  end

  test "user has many tags" do
    assert_includes users(:one).tags, tags(:work)
    assert_not_includes users(:one).tags, tags(:other_users)
  end

  test "to_param round trip" do
    tag = Tag.create!(user: users(:one), name: "新規", memo_use: "enabled")
    assert_match(/\A[#{Base58Uuid::BASE58_ALPHABET}]{22}\z/o, tag.to_param)
    assert_equal tag, Tag.find_uuid(tag.to_param)
  end
end
