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

  test "with_counts has the number of the reminders" do
    tags = users(:one).tags.with_counts.order(:name).index_by(&:name)
    assert_equal 1, tags[tags(:work).name].reminders_count
    assert_equal 0, tags[tags(:medicine).name].reminders_count
    assert_equal users(:one).tags.count, tags.size
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
