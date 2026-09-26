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

  test "should get new prefilled from a reminder" do
    get new_memo_url(reminder_id: reminders(:lunch_medicine).to_param)
    assert_response :success
    assert_select "form#new_memo" do
      assert_select "textarea[name=?]", "memo[content]", text: "昼の薬を飲んだ"
      assert_select "input[type=checkbox][checked][name=?][value=?]", "memo[tags][]", "薬"
      assert_select "input[type=checkbox]:not([checked])[name=?][value=?]", "memo[tags][]", "tag1"
    end
  end

  test "should get new without prefill from another user's or an unknown reminder" do
    [reminders(:others_reminder).to_param, SecureRandom.uuid_v7, "0" * 22, "unknown"].each do |reminder_id|
      get new_memo_url(reminder_id:)
      assert_response :success
      assert_select "textarea[name=?]", "memo[content]", text: ""
      assert_select "input[type=checkbox][checked][name=?]", "memo[tags][]", count: 0
    end
  end

  test "new shows urgent reminders above the form and the others below it" do
    travel_to_base_time
    get new_memo_url
    assert_response :success

    body = response.body
    assert_operator body.index('id="urgent_reminders"'), :<, body.index('id="new_memo"')
    assert_operator body.index('id="new_memo"'), :<, body.index('id="active_reminders"')
    assert_equal %i[tax_papers lunch_medicine].map { reminders(it).name }, card_names("#urgent_reminders")
    assert_equal %i[work_report water github_streak recorded_show far_shinjuku near_station].map { reminders(it).name },
      card_names("#active_reminders")
  end

  test "reminder cards on new show the state, the tags and a button to complete" do
    travel_to_base_time
    reminders(:water).update!(last_completed_at: 3.hours.ago, completed_count: 2)
    get new_memo_url

    assert_select "#urgent_reminders .reminder-card.border-secondary", text: /確定申告の書類を集める/ do
      assert_select ".badge.badge-danger", "期限切れ"
      assert_select "form[action=?] button.btn.btn-sm.btn-outline-success", complete_reminder_path(reminders(:tax_papers)), "完了"
    end
    assert_select "#urgent_reminders .reminder-card.border-success", text: /昼の薬/ do
      assert_select "*", /あと 31分/
      assert_select ".badge.badge-success", "健康"
      assert_select ".small", "食後に飲む"
    end
    assert_select "#active_reminders .reminder-card", text: /水を飲む/ do
      assert_select "*", /あと 11時間59分/
      assert_select "*", /本日 2\/8回/
    end
  end

  test "new does not show disabled, disabled-tagged, waiting or other users' reminders" do
    travel_to_base_time
    get new_memo_url

    shown = card_names("#urgent_reminders") + card_names("#active_reminders")
    %i[paused archived_hobby mwf_gym second_tuesday others_reminder].each do |name|
      assert_not_includes shown, reminders(name).name
    end
  end

  test "new does not show reminders with a tag hidden on this device" do
    travel_to_base_time
    cookies[:hidden_tag_ids] = [tags(:work).id, tags(:health).id].join(",")
    get new_memo_url

    shown = card_names("#urgent_reminders") + card_names("#active_reminders")
    assert_not_includes shown, reminders(:work_report).name
    assert_not_includes shown, reminders(:lunch_medicine).name
    assert_includes shown, reminders(:github_streak).name
  end

  test "new ignores garbage and other users' tag ids in the cookie of hidden tags" do
    travel_to_base_time
    cookies[:hidden_tag_ids] = ["garbage", tags(:other_users).id, "", "'; DROP TABLE tags; --"].join(",")
    get new_memo_url

    assert_response :success
    assert_equal 8, (card_names("#urgent_reminders") + card_names("#active_reminders")).size
  end

  test "new has no reminder sections without actionable reminders" do
    travel_to_base_time
    users(:one).reminders.destroy_all
    users(:one).tags.destroy_all
    get new_memo_url

    assert_response :success
    assert_select "#urgent_reminders", 0
    assert_select "#active_reminders", 0
    assert_select "#hidden_tags_form", 0
  end

  test "new has a form to hide tags on this device" do
    travel_to_base_time
    cookies[:hidden_tag_ids] = tags(:health).id
    get new_memo_url

    assert_select "button[data-toggle=collapse][data-target=?]", "#hidden_tags_form", "この端末で非表示にするタグ"
    assert_select "form#hidden_tags_form.collapse[action=?]", hidden_tags_path do
      assert_select "input[type=hidden][name=?][value='']", "tag_ids[]"
      assert_select "input[type=checkbox][name=?]", "tag_ids[]", 2
      assert_select "input[type=checkbox]:not([checked])[value=?]", tags(:work).id
      assert_select "input[type=checkbox][checked][value=?]", tags(:health).id
      assert_select "label", "健康"
    end
  end

  test "should create memo" do
    assert_difference("Memo.count") do
      post memos_url, params: { memo: { content: @memo.content, create_from: @memo.create_from, info: @memo.info, price: @memo.price, tags: @memo.tags, user_id: @memo.user_id } }
    end

    assert_redirected_to memo_url(Memo.order(:created_at).last)
  end

  test "should render new with reminders and 422 when the memo is not saved" do
    travel_to_base_time
    with_failing_memo_save do
      assert_no_difference("Memo.count") do
        post memos_url, params: { memo: { content: "未保存" } }
      end
    end

    assert_response :unprocessable_content
    assert_select "form#new_memo textarea[name=?]", "memo[content]", text: "未保存"
    assert_select "#urgent_reminders .reminder-card", 2
    assert_select "#active_reminders .reminder-card", 6
  end

  test "should show memo" do
    get memo_url(@memo)
    assert_response :success
  end

  test "should not show memo with valid random uuid_v4" do
    get memo_url(SecureRandom.uuid_v4)
    assert_response :not_found
  end

  test "should not show memo with valid random uuid_v7" do
    get memo_url(SecureRandom.uuid_v7)
    assert_response :not_found
  end

  test "should not show memo with invalid uuid_v4 length" do
    get memo_url(SecureRandom.uuid_v4 + "x")
    assert_response :not_found
  end

  test "should not show memo with invalid uuid_v7 length" do
    get memo_url(SecureRandom.uuid_v7 + "x")
    assert_response :not_found
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

  # Base time of the reminder fixtures (Wednesday)
  private def travel_to_base_time = travel_to(Time.zone.local(2026, 1, 7, 12, 0))

  # No validation of Memo fails by request parameters, so save is replaced while the block runs
  private def with_failing_memo_save
    Memo.define_method(:save) { |**| false }
    yield
  ensure
    Memo.remove_method(:save)
  end

  private def card_names(section) = css_select("#{section} .reminder-card .card-title a").map(&:text)
end
