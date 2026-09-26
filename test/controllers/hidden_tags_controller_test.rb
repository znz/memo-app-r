# frozen_string_literal: true

require "test_helper"

class HiddenTagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    travel_to Time.zone.local(2026, 1, 7, 12, 0)
    user = users(:one)
    user.confirm
    sign_in user
  end

  test "should save the hidden tags in a cookie" do
    post hidden_tags_url, params: { tag_ids: ["", tags(:work).id, tags(:health).id] }

    assert_redirected_to new_memo_url
    assert_equal "この端末で非表示にするタグを保存しました。", flash[:notice]
    assert_equal [tags(:work).id, tags(:health).id].sort, hidden_tag_ids_in_cookie.sort
    set_cookie = Array(response.headers["set-cookie"]).join("\n")
    assert_match(/hidden_tag_ids=.*; expires=.*; httponly; samesite=lax/i, set_cookie)

    follow_redirect!
    shown = css_select(".reminder-card .card-title a").map(&:text)
    assert_not_includes shown, reminders(:work_report).name
    assert_not_includes shown, reminders(:lunch_medicine).name
    assert_includes shown, reminders(:github_streak).name
  end

  test "should save only own tags" do
    post hidden_tags_url, params: { tag_ids: ["", "garbage", SecureRandom.uuid_v7, tags(:other_users).id, tags(:health).id] }

    assert_redirected_to new_memo_url
    assert_equal [tags(:health).id], hidden_tag_ids_in_cookie
  end

  test "should delete the cookie when no tag is checked" do
    post hidden_tags_url, params: { tag_ids: [tags(:work).id] }
    assert_equal [tags(:work).id], hidden_tag_ids_in_cookie

    post hidden_tags_url, params: { tag_ids: [""] }

    assert_redirected_to new_memo_url
    assert_empty hidden_tag_ids_in_cookie
    assert_match(/hidden_tag_ids=; .*expires=Thu, 01 Jan 1970/i, Array(response.headers["set-cookie"]).join("\n"))
  end

  test "should redirect back to the referer" do
    post hidden_tags_url, params: { tag_ids: [""] }, headers: { "HTTP_REFERER" => memo_url(memos(:one)) }

    assert_redirected_to memo_url(memos(:one))
  end

  test "should respond bad request without tag_ids" do
    post hidden_tags_url, params: { tag_ids: "garbage" }

    assert_response :bad_request
  end

  private def hidden_tag_ids_in_cookie = CGI.unescape(cookies["hidden_tag_ids"].to_s).split(",")
end
