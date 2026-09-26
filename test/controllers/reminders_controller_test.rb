# frozen_string_literal: true

require "test_helper"

class RemindersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    travel_to Time.zone.local(2026, 1, 7, 12, 0)
    user = users(:one)
    user.confirm
    sign_in user
    @reminder = reminders(:work_report)
  end

  test "should get index with own reminders only" do
    get reminders_url
    assert_response :success
    assert_select "h1", "リマインダー一覧"
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@reminder)}" do
      assert_select "a[href=?]", reminder_path(@reminder), text: "日報"
      assert_select "span.badge.badge-primary", "仕事"
      assert_select "td", "毎週 月・火・水・木・金"
      assert_select "td", "実行可能"
    end
    assert_select "a", text: reminders(:paused).name
    assert_select "a", text: reminders(:others_reminder).name, count: 0
  end

  test "nav has a link to reminders" do
    get reminders_url
    assert_select "nav li.active a.nav-link[href=?]", reminders_path, text: /リマインダー/
  end

  test "should get new" do
    get new_reminder_url
    assert_response :success
    assert_select "h1", "新規リマインダー"
    assert_select "form[action=?]", reminders_path do
      assert_select "input[name=?]", "reminder[name]"
      assert_select "textarea[name=?]", "reminder[description]"
      assert_select "textarea[name=?]", "reminder[memo_template]"
      assert_select "input[type=checkbox][name=?][value=?]", "reminder[memo_tags][]", "tag1"
      assert_select "input[type=text][name=?]", "reminder[memo_tags][]"
      assert_select "input[type=checkbox][name=?]", "reminder[enabled]"
      %w[starts_at due_at repeat_until].each do |name|
        assert_select "input[type=datetime-local][name=?]", "reminder[#{name}]"
      end
      assert_select "select[name=?]", "reminder[recurrence_preset]" do
        assert_select "option", Recurrence::PRESETS.size
        assert_select "option[selected][value=none]", "単発"
      end
      assert_select "textarea[name=?]", "reminder[recurrence_json]"
      assert_select "input[type=number][name=?]", "reminder[latitude]"
      assert_select "input[type=number][name=?]", "reminder[longitude]"
      assert_select "input[type=number][name=?][value=?]", "reminder[radius_m]", "200"
      assert_select "input[type=checkbox][name=?][value=?]", "reminder[tag_ids][]", tags(:work).id
      assert_select "input[type=checkbox][name=?][value=?]", "reminder[tag_ids][]", tags(:other_users).id, count: 0
    end
  end

  test "should get new with the location of a memo" do
    get new_reminder_url(reminder: { latitude: "35.6817", longitude: "139.7671", name: "ignored" })
    assert_response :success
    assert_select "input[name=?][value=?]", "reminder[latitude]", "35.6817"
    assert_select "input[name=?][value=?]", "reminder[longitude]", "139.7671"
    assert_select "input[name=?]:not([value])", "reminder[name]"
  end

  test "should create reminder with a preset" do
    assert_difference("users(:one).reminders.count") do
      post reminders_url, params: { reminder: {
        name: "朝会", description: "10分", memo_template: "朝会メモ", memo_tags: ["", "tag1", "会議"],
        enabled: "1", starts_at: "2026-01-08T09:30", due_at: "2026-01-08T09:44", repeat_until: "",
        recurrence_preset: "weekdays", recurrence_json: "", latitude: "35.6817", longitude: "139.7671", radius_m: "300",
        tag_ids: ["", tags(:work).id]
      } }
    end

    reminder = users(:one).reminders.find_by!(name: "朝会")
    assert_redirected_to reminder_url(reminder)
    assert_equal "リマインダーが作成されました。", flash[:notice]
    assert_equal({ "type" => "weekly", "weekdays" => [1, 2, 3, 4, 5] }, reminder.recurrence)
    assert_equal Time.zone.local(2026, 1, 8, 9, 30), reminder.starts_at
    assert_equal Time.zone.local(2026, 1, 8, 9, 44), reminder.due_at
    assert_nil reminder.repeat_until
    assert_equal ["tag1", "会議"], reminder.memo_tags
    assert_equal [tags(:work)], reminder.tags.to_a
    assert_equal [35.6817, 139.7671, 300], [reminder.lonlat.y, reminder.lonlat.x, reminder.radius_m]
    assert_equal ["10分", "朝会メモ", true], [reminder.description, reminder.memo_template, reminder.enabled]
  end

  test "should create reminder with JSON in preference to the preset" do
    post reminders_url, params: { reminder: {
      name: "燃えるゴミ", starts_at: "2026-01-08T06:00", recurrence_preset: "daily",
      recurrence_json: '{"type": "monthly", "nth": -1, "weekday": "business"}'
    } }

    reminder = users(:one).reminders.find_by!(name: "燃えるゴミ")
    assert_redirected_to reminder_url(reminder)
    assert_equal({ "type" => "monthly", "nth" => -1, "weekday" => "business" }, reminder.recurrence)
  end

  test "should not create reminder with invalid attributes" do
    assert_no_difference("Reminder.count") do
      post reminders_url, params: { reminder: { name: "", recurrence_json: "{", memo_tags: ["", "会議"] } }
    end

    assert_response :unprocessable_content
    assert_select "form[action=?]", reminders_path do
      assert_select ".reminder_name .invalid-feedback"
      assert_select ".reminder_recurrence_json .invalid-feedback", /JSONとして読み取れません/
      assert_select "textarea[name=?]", "reminder[recurrence_json]", text: "{"
      assert_select "input[type=checkbox][checked][name=?][value=?]", "reminder[memo_tags][]", "会議"
    end
  end

  test "should not create reminder with another user's tag" do
    assert_no_difference(["Reminder.count", "ReminderTag.count"]) do
      post reminders_url, params: { reminder: { name: "盗み見", tag_ids: [tags(:other_users).id] } }
    end

    assert_response :unprocessable_content
    assert_select ".reminder_tags .invalid-feedback", /他のユーザーのタグは使えません/
  end

  test "should show reminder" do
    get reminder_url(reminders(:lunch_medicine))
    assert_response :success
    assert_select "h1", "昼の薬"
    assert_select "dd span.badge.badge-success", "健康"
    assert_select "dd", "毎日"
    assert_select "dd", "実行可能"
    assert_select "dd", "2026/01/07 09:00 〜 2026/01/07 12:30"
    assert_select "dd", "2026/01/08 09:00 〜 2026/01/08 12:30"
    assert_select "dd pre", JSON.pretty_generate({ "type" => "daily" })
    assert_select "a[href=?]", edit_reminder_path(reminders(:lunch_medicine))
    assert_select "form[action=?] input[name=_method][value=delete]", reminder_path(reminders(:lunch_medicine))
  end

  test "should get edit" do
    get edit_reminder_url(@reminder)
    assert_response :success
    assert_select "h1", "リマインダー編集"
    assert_select "form[action=?]", reminder_path(@reminder) do
      assert_select "input[type=datetime-local][name=?][value=?]", "reminder[starts_at]", "2026-01-05T09:00"
      assert_select "input[type=datetime-local][name=?][value=?]", "reminder[due_at]", "2026-01-05T19:00"
      assert_select "input[type=datetime-local][name=?]:not([value])", "reminder[repeat_until]"
      assert_select "select[name=?] option:first-child[value='']", "reminder[recurrence_preset]", "（変更しない）"
      assert_select "select[name=?] option[selected]", "reminder[recurrence_preset]", count: 0
      assert_select "textarea[name=?]", "reminder[recurrence_json]", text: JSON.pretty_generate(@reminder.recurrence)
      assert_select "input[type=checkbox][checked][name=?][value=?]", "reminder[tag_ids][]", tags(:work).id
    end
  end

  test "should update reminder" do
    patch reminder_url(@reminder), params: { reminder: {
      name: "週報", recurrence_preset: "", recurrence_json: '{"type": "weekly", "weekdays": [5]}',
      tag_ids: ["", tags(:health).id], latitude: "", longitude: ""
    } }

    assert_redirected_to reminder_url(@reminder)
    assert_equal "リマインダーが更新されました。", flash[:notice]
    @reminder.reload
    assert_equal "週報", @reminder.name
    assert_equal({ "type" => "weekly", "weekdays" => [5] }, @reminder.recurrence)
    assert_equal [tags(:health)], @reminder.tags.to_a
  end

  test "should update reminder with a preset when the JSON shown in the edit form is left as is" do
    patch reminder_url(@reminder), params: { reminder: {
      recurrence_preset: "daily", recurrence_json: JSON.pretty_generate(@reminder.recurrence)
    } }

    assert_redirected_to reminder_url(@reminder)
    assert_equal({ "type" => "daily" }, @reminder.reload.recurrence)
  end

  test "should keep the rule when neither the preset nor the JSON is changed" do
    patch reminder_url(@reminder), params: { reminder: {
      name: "日報2", recurrence_preset: "", recurrence_json: JSON.pretty_generate(@reminder.recurrence)
    } }

    assert_redirected_to reminder_url(@reminder)
    @reminder.reload
    assert_equal "日報2", @reminder.name
    assert_equal({ "type" => "weekly", "weekdays" => [1, 2, 3, 4, 5] }, @reminder.recurrence)
  end

  test "should not update reminder with invalid attributes" do
    patch reminder_url(@reminder), params: { reminder: { due_at: "2026-01-05T08:00", latitude: "35.6" } }

    assert_response :unprocessable_content
    assert_select ".reminder_due_at .invalid-feedback", /通知開始日時より後/
    assert_select ".reminder_latitude .invalid-feedback", /両方指定/
    assert_equal Time.zone.local(2026, 1, 5, 19, 0), @reminder.reload.due_at
  end

  test "should destroy reminder" do
    assert_difference(["Reminder.count", "ReminderTag.count"], -1) do
      delete reminder_url(@reminder)
    end

    assert_redirected_to reminders_url
    assert_response :see_other
    assert_equal "リマインダーが削除されました。", flash[:notice]
  end

  test "index has links to new and edit" do
    get reminders_url
    assert_select "a[href=?]", new_reminder_path
    assert_select "a[href=?]", edit_reminder_path(@reminder)
  end

  # A request raising RecordNotFound does not commit the session, so each test makes only one such request
  test "should not show another user's reminder" do
    get reminder_url(reminders(:others_reminder))
    assert_response :not_found
  end

  test "should not edit another user's reminder" do
    get edit_reminder_url(reminders(:others_reminder))
    assert_response :not_found
  end

  test "should not update another user's reminder" do
    patch reminder_url(reminders(:others_reminder)), params: { reminder: { name: "奪取" } }
    assert_response :not_found
    assert_equal "他人のリマインダー", reminders(:others_reminder).reload.name
  end

  test "should not destroy another user's reminder" do
    assert_no_difference("Reminder.count") do
      delete reminder_url(reminders(:others_reminder))
    end
    assert_response :not_found
  end
end
