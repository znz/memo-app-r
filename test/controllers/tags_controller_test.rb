# frozen_string_literal: true

require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    travel_to Time.zone.local(2026, 1, 7, 12, 0)
    user = users(:one)
    user.confirm
    sign_in user
    @tag = tags(:work)
  end

  test "should get index with own tags only" do
    get tags_url
    assert_response :success
    assert_select "h1", "タグ一覧"
    assert_select "td span.badge.badge-primary", tags(:work).name
    assert_select "td span.badge", text: tags(:archived).name
    assert_select "td span.badge", text: tags(:other_users).name, count: 0
  end

  test "should get new" do
    get new_tag_url
    assert_response :success
    assert_select "form[action=?]", tags_path do
      assert_select "input[name=?]", "tag[name]"
      assert_select "select[name=?] option[value=?]", "tag[color]", "success", text: "緑 (success)"
      assert_select "input[type=checkbox][name=?]", "tag[enabled]"
    end
  end

  test "should create tag" do
    assert_difference("users(:one).tags.count") do
      post tags_url, params: { tag: { name: "買い物", color: "warning", enabled: "1" } }
    end

    assert_redirected_to tags_url
    assert_equal "タグが作成されました。", flash[:notice]
    tag = users(:one).tags.find_by!(name: "買い物")
    assert_equal "warning", tag.color
    assert tag.enabled?
  end

  test "should not create tag with a duplicate name" do
    assert_no_difference("Tag.count") do
      post tags_url, params: { tag: { name: @tag.name, color: "primary" } }
    end

    assert_response :unprocessable_content
    assert_select "form[action=?] .invalid-feedback", tags_path
  end

  test "should create tag with the name of another user's tag" do
    assert_difference("users(:one).tags.count") do
      post tags_url, params: { tag: { name: tags(:other_users).name, color: "primary" } }
    end

    assert_redirected_to tags_url
  end

  test "should get edit" do
    get edit_tag_url(@tag)
    assert_response :success
    assert_select "h1", "タグ編集"
    assert_select "form[action=?] input[name=?][value=?]", tag_path(@tag), "tag[name]", @tag.name
  end

  test "should update tag" do
    patch tag_url(@tag), params: { tag: { name: "仕事2", color: "danger", enabled: "0" } }

    assert_redirected_to tags_url
    assert_equal "タグが更新されました。", flash[:notice]
    @tag.reload
    assert_equal ["仕事2", "danger", false], [@tag.name, @tag.color, @tag.enabled]
  end

  test "should not update tag with an invalid color" do
    patch tag_url(@tag), params: { tag: { color: "pink" } }

    assert_response :unprocessable_content
    assert_equal "primary", @tag.reload.color
  end

  test "should destroy tag" do
    assert_difference("Tag.count", -1) do
      delete tag_url(@tag)
    end

    assert_redirected_to tags_url
    assert_response :see_other
    assert_equal "タグが削除されました。", flash[:notice]
    assert_not ReminderTag.exists?(tag_id: @tag.id)
  end

  test "index has links to new, edit and destroy" do
    get tags_url
    assert_select "a[href=?]", new_tag_path
    assert_select "a[href=?]", edit_tag_path(@tag)
    assert_select "form[action=?] input[name=_method][value=delete]", tag_path(@tag)
  end

  # A request raising RecordNotFound does not commit the session, so each test makes only one such request
  test "should not edit another user's tag" do
    get edit_tag_url(tags(:other_users))
    assert_response :not_found
  end

  test "should not update another user's tag" do
    patch tag_url(tags(:other_users)), params: { tag: { name: "奪取" } }
    assert_response :not_found
    assert_equal "他人のタグ", tags(:other_users).reload.name
  end

  test "should not destroy another user's tag" do
    assert_no_difference("Tag.count") do
      delete tag_url(tags(:other_users))
    end
    assert_response :not_found
  end

  test "nav has a link to tags" do
    get tags_url
    assert_select "nav a.nav-link[href=?]", tags_path, text: /タグ/
  end
end
