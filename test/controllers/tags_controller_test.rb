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

  test "index shows the uses, the numbers of the memos and the reminders and the last use by a memo" do
    memos(:one).update!(created_at: Time.zone.local(2026, 1, 5, 10, 0))
    get tags_url
    assert_equal ["名前", "色", "メモ", "リマインダー", "メモ数", "メモの最終使用日", "リマインダー数", ""], css_select("thead th").map(&:text)
    assert_select "tr[id=?]", dom_id(tags(:work)) do
      assert_select "td:nth-child(3)", "有効"
      assert_select "td:nth-child(4)", "有効"
      assert_select "td:nth-child(5)", "0"
      assert_select "td:nth-child(6)", ""
      assert_select "td:nth-child(7)", "1"
    end
    assert_select "tr[id=?]", dom_id(tags(:tag1)) do
      assert_select "td:nth-child(5)", "1"
      assert_select "td:nth-child(6)", "2026/01/05"
      assert_select "td:nth-child(7)", "0"
    end
    assert_select "tr[id=?]", dom_id(tags(:archived)) do
      assert_select "td:nth-child(3)", "—"
      assert_select "td:nth-child(4)", "無効"
    end
    assert_select "tr[id=?]", dom_id(tags(:medicine)) do
      assert_select "td:nth-child(3)", "有効"
      assert_select "td:nth-child(4)", "—"
      assert_select "td:nth-child(7)", "0"
    end
  end

  test "index has no destroy button for a tag on memos" do
    get tags_url
    assert_select "form[action=?] input[name=_method][value=delete]", tag_path(tags(:tag1)), count: 0
    assert_select "form[action=?] input[name=_method][value=delete]", tag_path(tags(:medicine))
  end

  test "should not destroy a tag on memos" do
    assert_no_difference("Tag.count") do
      delete tag_url(tags(:tag1))
    end

    assert_redirected_to tags_url
    assert_equal "メモが存在しているので削除できません", flash[:alert]
  end

  test "should not update the memo use to unused while memos have the tag" do
    patch tag_url(tags(:tag1)), params: { tag: { memo_use: "unused", reminder_use: "enabled" } }

    assert_response :unprocessable_content
    assert_select ".tag_memo_use .invalid-feedback", /1件のメモかリマインダーに付いているので「使わない」にできません/
    assert tags(:tag1).reload.memo_enabled?
  end

  test "should get new" do
    get new_tag_url
    assert_response :success
    assert_select "form[action=?]", tags_path do
      assert_select "input[name=?]", "tag[name]"
      assert_select "select[name=?] option[value=?]", "tag[color]", "success", text: "緑 (success)"
      assert_select "select[name=?]", "tag[memo_use]" do
        assert_select "option", 3
        assert_select "option[selected][value=enabled]", "有効"
        assert_select "option[value=unused]", "使わない"
        assert_select "option[value=disabled]", "無効（新規メモでは使わない）"
      end
      assert_select "select[name=?]", "tag[reminder_use]" do
        assert_select "option", 3
        assert_select "option[selected][value=enabled]", "有効"
        assert_select "option[value=disabled]", "無効（リマインダーを非表示）"
      end
    end
  end

  test "should create tag" do
    assert_difference("users(:one).tags.count") do
      post tags_url, params: { tag: { name: "買い物", color: "warning", memo_use: "enabled", reminder_use: "unused" } }
    end

    assert_redirected_to tags_url
    assert_equal "タグが作成されました。", flash[:notice]
    tag = users(:one).tags.find_by!(name: "買い物")
    assert_equal %w[warning enabled unused], [tag.color, tag.memo_use, tag.reminder_use]
  end

  test "should not create tag with a duplicate name" do
    assert_no_difference("Tag.count") do
      post tags_url, params: { tag: { name: @tag.name, color: "primary", memo_use: "enabled" } }
    end

    assert_response :unprocessable_content
    assert_select "form[action=?] .invalid-feedback", tags_path
  end

  test "should create tag with the name of another user's tag" do
    assert_difference("users(:one).tags.count") do
      post tags_url, params: { tag: { name: tags(:other_users).name, color: "primary", memo_use: "enabled" } }
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
    patch tag_url(@tag), params: { tag: { name: "仕事2", color: "danger", memo_use: "disabled", reminder_use: "disabled" } }

    assert_redirected_to tags_url
    assert_equal "タグが更新されました。", flash[:notice]
    @tag.reload
    assert_equal %w[仕事2 danger disabled disabled], [@tag.name, @tag.color, @tag.memo_use, @tag.reminder_use]
  end

  test "should not update the reminder use to unused while reminders have the tag" do
    patch tag_url(@tag), params: { tag: { reminder_use: "unused" } }

    assert_response :unprocessable_content
    assert_select ".tag_reminder_use .invalid-feedback", /1件のリマインダーに付いているので「使わない」にできません/
    assert @tag.reload.reminder_enabled?
  end

  test "should not create tag used for nothing" do
    assert_no_difference("Tag.count") do
      post tags_url, params: { tag: { name: "買い物", memo_use: "unused", reminder_use: "unused" } }
    end

    assert_response :unprocessable_content
    assert_select "form .alert", /メモかリマインダーのどちらかで使うようにしてください/
  end

  test "edit selects the uses of the tag" do
    get edit_tag_url(tags(:archived))
    assert_select "select[name=?] option[selected][value=unused]", "tag[memo_use]"
    assert_select "select[name=?] option[selected][value=disabled]", "tag[reminder_use]"
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
