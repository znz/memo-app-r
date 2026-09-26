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
    tag = Tag.new(user: users(:two), name: tags(:work).name)
    assert tag.valid?
  end

  test "defaults" do
    tag = Tag.new
    assert tag.enabled?
    assert_equal "secondary", tag.color
  end

  test "color must be a theme color" do
    tag = Tag.new(user: users(:one), name: "新規", color: "pink")
    assert_not tag.valid?
    assert tag.errors.of_kind?(:color, :inclusion)
  end

  test "every theme color is accepted" do
    ThemeColor::COLORS.each do |color|
      assert Tag.new(user: users(:one), name: "新規", color:).valid?, color
    end
  end

  test "enabled scope" do
    assert_includes Tag.enabled, tags(:work)
    assert_not_includes Tag.enabled, tags(:archived)
  end

  test "user has many tags" do
    assert_includes users(:one).tags, tags(:work)
    assert_not_includes users(:one).tags, tags(:other_users)
  end

  test "to_param round trip" do
    tag = Tag.create!(user: users(:one), name: "新規")
    assert_match(/\A[#{Base58Uuid::BASE58_ALPHABET}]{22}\z/o, tag.to_param)
    assert_equal tag, Tag.find_uuid(tag.to_param)
  end
end
