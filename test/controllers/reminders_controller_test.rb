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

  private def row_ids = css_select("tbody tr").pluck("id")

  private def dom_ids(*names) = names.map { ActionView::RecordIdentifier.dom_id(reminders(it)) }

  test "index is sorted by name by default or with an unknown sort" do
    expected = users(:one).reminders.order(:name).map { ActionView::RecordIdentifier.dom_id(it) }
    get reminders_url
    assert_equal expected, row_ids

    get reminders_url(sort: "unknown")
    assert_equal expected, row_ids
  end

  test "index sorted like the new memo page has the actionable reminders first, including the hidden ones" do
    cookies[:hidden_tag_ids] = tags(:work).id
    get reminders_url(sort: "board")
    assert_response :success
    actionable = dom_ids(:tax_papers, :start_now, :weigh_in, :lunch_medicine,
      :work_report, :water, :github_streak, :archived_hobby, :recorded_show, :far_shinjuku, :near_station)
    others = users(:one).reminders.order(:name).map { ActionView::RecordIdentifier.dom_id(it) } & dom_ids(:paused, :mwf_gym, :second_tuesday)
    assert_equal actionable + others, row_ids
  end

  test "index has a switch of the order" do
    get reminders_url
    assert_select ".reminders-sort", /並び順:/ do
      assert_select "strong", "名前順"
      assert_select "a", count: 1
      assert_select "a[href=?]", reminders_path(sort: "board"), "未完了を新規メモ画面と同じ順に"
    end

    get reminders_url(sort: "board")
    assert_select ".reminders-sort" do
      assert_select "strong", "未完了を新規メモ画面と同じ順に"
      assert_select "a", count: 1
      assert_select "a[href=?]", reminders_path, "名前順"
    end
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
      %w[starts_at due_at prioritize_at repeat_until].each do |name|
        assert_select "input[type=datetime-local][name=?]", "reminder[#{name}]"
      end
      assert_select ".reminder_prioritize_at small", /通知開始日時と同じにすると実行可能になった時点で上に出ます/
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

  test "new and edit show the tags of the reminder as colored badges" do
    [new_reminder_url, edit_reminder_url(@reminder)].each do |url|
      get url
      assert_response :success
      assert_select "label[for=?] span.badge.badge-primary", "reminder_tag_ids_#{tags(:work).id}", "仕事"
      assert_select "label[for=?] span.badge.badge-success", "reminder_tag_ids_#{tags(:health).id}", "健康"
      assert_select "label[for=?]", "reminder_tag_ids_#{tags(:work).id}", text: /span/, count: 0
    end
  end

  test "badges of the tags on the form escape the name" do
    tag = users(:one).tags.create!(name: "<b>x</b>", color: "danger")
    get new_reminder_url
    assert_select "label[for=?] span.badge.badge-danger", "reminder_tag_ids_#{tag.id}", "<b>x</b>"
    assert_select "label[for=?] b", "reminder_tag_ids_#{tag.id}", count: 0
  end

  test "memo_tags check boxes are not badges" do
    get new_reminder_url
    assert_select "label[for=?]", "reminder_memo_tags_tag1", "tag1"
    assert_select "label[for=?] span.badge", "reminder_memo_tags_tag1", count: 0
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
        enabled: "1", starts_at: "2026-01-08T09:30", due_at: "2026-01-08T09:44", prioritize_at: "2026-01-08T09:40", repeat_until: "",
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
    assert_equal Time.zone.local(2026, 1, 8, 9, 40), reminder.prioritize_at
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

  test "should create after_completion reminder with cooldown_days and due_days" do
    post reminders_url, params: { reminder: {
      name: "エアコンのフィルター掃除", recurrence_preset: "",
      recurrence_json: '{"type": "after_completion", "cooldown_days": 150, "due_days": 30}'
    } }

    reminder = users(:one).reminders.find_by!(name: "エアコンのフィルター掃除")
    assert_redirected_to reminder_url(reminder)
    assert_equal({ "type" => "after_completion", "cooldown_days" => 150, "due_days" => 30 }, reminder.recurrence)
    follow_redirect!
    assert_select "dd", "完了日から150日後（期限30日）"
  end

  test "should not create reminder with invalid attributes" do
    assert_no_difference("Reminder.count") do
      post reminders_url, params: { reminder: { name: "", recurrence_json: "{", memo_tags: ["", "会議"] } }
    end

    assert_response :unprocessable_content
    assert_select "form[action=?]", reminders_path do
      assert_select ".alert.alert-danger", "入力内容を確認してください:"
      assert_select ".reminder_name label abbr[title=?]", "必須", "*"
      assert_select ".reminder_name .invalid-feedback"
      assert_select ".reminder_recurrence_json .invalid-feedback", count: 1
      assert_select ".reminder_recurrence_json .invalid-feedback", /JSONとして読み取れません/
      assert_select "textarea.is-invalid[name=?]", "reminder[recurrence_json]", text: "{"
      assert_select "input[type=checkbox][checked][name=?][value=?]", "reminder[memo_tags][]", "会議"
    end
  end

  test "should show the error of the rule given by JSON" do
    assert_no_difference("Reminder.count") do
      post reminders_url, params: { reminder: { name: "燻煙剤", recurrence_json: '{"type":"after_completion","due_days":30}' } }
    end

    assert_response :unprocessable_content
    assert_select ".reminder_recurrence_json .invalid-feedback", count: 1
    assert_select ".reminder_recurrence_json .invalid-feedback", "繰り返しにはcooldown_minutesかcooldown_daysを指定してください"
    assert_select ".reminder_recurrence_json textarea.is-invalid + .invalid-feedback"
    assert_select "textarea[name=?]", "reminder[recurrence_json]", text: '{"type":"after_completion","due_days":30}'
  end

  test "should not show an error of the rule when the rule is valid" do
    post reminders_url, params: { reminder: { name: "", recurrence_json: '{"type":"after_completion","cooldown_days":60}' } }

    assert_response :unprocessable_content
    assert_select ".reminder_name .invalid-feedback"
    assert_select ".reminder_recurrence_json .invalid-feedback", count: 0
    assert_select "textarea.is-invalid[name=?]", "reminder[recurrence_json]", count: 0
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
    assert_select "dt", "優先開始日時"
    assert_select "a[href=?]", edit_reminder_path(reminders(:lunch_medicine))
    assert_select "form[action=?] input[name=_method][value=delete]", reminder_path(reminders(:lunch_medicine))
  end

  test "should show overdue reminder between windows" do
    travel_to Time.zone.local(2026, 1, 7, 13, 0)
    reminder = reminders(:lunch_medicine)
    reminder.update!(recurrence: { "type" => "daily", "overdue" => true })
    get reminder_url(reminder)
    assert_response :success
    assert_select "dd", "期限切れ"
    assert_select "dd", "毎日（期限後も表示）"
    assert_select "dt", "現在の枠"
    assert_select "dd", "2026/01/07 09:00 〜 2026/01/07 12:30"
    assert_select "dt", "次の枠"
    assert_select "dd", "2026/01/08 09:00 〜 2026/01/08 12:30"
  end

  test "should show reminder with location" do
    reminder = reminders(:near_station)
    get reminder_url(reminder)
    assert_response :success
    assert_select "dd", "緯度 35.6817 経度 139.7671（半径 200m）"
  end

  test "should show after_completion reminder" do
    reminder = reminders(:water)
    get reminder_url(reminder)
    assert_response :success
    assert_select "h1", reminder.name
    assert_select "dd", reminder.rule.label
  end

  test "index and show have prioritize_at" do
    @reminder.update!(prioritize_at: Time.zone.local(2026, 1, 5, 18, 0))
    get reminders_url
    assert_select "th", "優先開始日時"
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@reminder)} td", "01/05 18:00"

    get reminder_url(@reminder)
    assert_select "dt", "優先開始日時"
    assert_select "dd", "2026/01/05 18:00"
  end

  test "should get edit" do
    get edit_reminder_url(@reminder)
    assert_response :success
    assert_select "h1", "リマインダー編集"
    assert_select "form[action=?]", reminder_path(@reminder) do
      assert_select "input[type=datetime-local][name=?][value=?]", "reminder[starts_at]", "2026-01-05T09:00"
      assert_select "input[type=datetime-local][name=?][value=?]", "reminder[due_at]", "2026-01-05T19:00"
      assert_select "input[type=datetime-local][name=?]:not([value])", "reminder[prioritize_at]"
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

  test "should update prioritize_at" do
    patch reminder_url(@reminder), params: { reminder: { prioritize_at: "2026-01-05T09:00" } }

    assert_redirected_to reminder_url(@reminder)
    assert_equal Time.zone.local(2026, 1, 5, 9, 0), @reminder.reload.prioritize_at

    patch reminder_url(@reminder), params: { reminder: { prioritize_at: "" } }
    assert_nil @reminder.reload.prioritize_at
  end

  test "should not update prioritize_at out of the first window" do
    patch reminder_url(@reminder), params: { reminder: { prioritize_at: "2026-01-05T08:59" } }

    assert_response :unprocessable_content
    assert_select ".reminder_prioritize_at .invalid-feedback", /通知開始日時以降にしてください/
    assert_nil @reminder.reload.prioritize_at

    patch reminder_url(@reminder), params: { reminder: { prioritize_at: "2026-01-05T19:01" } }

    assert_response :unprocessable_content
    assert_select ".reminder_prioritize_at .invalid-feedback", /実行可能期限以前にしてください/
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

  test "should not update reminder with another user's tag" do
    patch reminder_url(@reminder), params: { reminder: { tag_ids: [tags(:other_users).id] } }

    assert_response :unprocessable_content
    assert_select ".reminder_tags .invalid-feedback", /他のユーザーのタグは使えません/
    assert_equal [tags(:work)], @reminder.reload.tags.to_a
  end

  test "should show the error of the rule on update" do
    patch reminder_url(@reminder), params: { reminder: { due_at: "", repeat_until: "", recurrence_preset: "", recurrence_json: '{"type":"daily","overdue":true}' } }

    assert_response :unprocessable_content
    assert_select ".reminder_recurrence_json .invalid-feedback", count: 1
    assert_select ".reminder_recurrence_json .invalid-feedback", "繰り返しのoverdueは実行可能期限か繰り返し終了日時と一緒に指定してください"
    assert_equal({ "type" => "weekly", "weekdays" => [1, 2, 3, 4, 5] }, @reminder.reload.recurrence)
  end

  test "should keep the JSON of the saved rule when an update with a preset fails" do
    patch reminder_url(@reminder), params: { reminder: {
      name: "", recurrence_preset: "daily", recurrence_json: JSON.pretty_generate(@reminder.recurrence)
    } }

    assert_response :unprocessable_content
    assert_select ".reminder_name .invalid-feedback"
    assert_select "select[name=?] option[selected][value=daily]", "reminder[recurrence_preset]"
    assert_select "textarea[name=?]", "reminder[recurrence_json]", text: JSON.pretty_generate(@reminder.recurrence)
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

  test "should complete reminder and redirect to a new memo" do
    reminder = reminders(:lunch_medicine)
    post complete_reminder_url(reminder)

    assert_redirected_to new_memo_url(reminder_id: reminder.to_param)
    assert_equal "「昼の薬」を完了しました。", flash[:notice]
    reminder.reload
    assert_equal({ "path" => undo_complete_reminder_path(reminder), "completed_at" => reminder.last_completed_at.iso8601(6) }, flash[:undo])
    assert_equal Time.current, reminder.last_completed_at
    assert_equal 1, reminder.completed_count
  end

  test "the new memo page after completion is prefilled and has a button to undo" do
    reminder = reminders(:lunch_medicine)
    post complete_reminder_url(reminder)
    follow_redirect!

    assert_response :success
    assert_select ".alert", /「昼の薬」を完了しました。/ do
      assert_select "form[action=?]", undo_complete_reminder_path(reminder) do
        assert_select "input[type=hidden][name=completed_at][value=?]", reminder.reload.last_completed_at.iso8601(6)
        assert_select "button.btn", "取り消す"
      end
    end
    assert_select "form#new_memo" do
      assert_select "textarea[name=?]", "memo[content]", text: "昼の薬を飲んだ"
      assert_select "input[type=checkbox][checked][name=?][value=?]", "memo[tags][]", "薬"
    end
  end

  test "should undo the completion" do
    reminder = reminders(:water)
    reminder.update!(last_completed_at: 2.hours.ago, completed_count: 3)
    post complete_reminder_url(reminder)
    completed_at = flash[:undo]["completed_at"]
    follow_redirect!
    assert_equal 4, reminder.reload.completed_count

    post undo_complete_reminder_url(reminder), params: { completed_at: }

    assert_redirected_to new_memo_url
    assert_equal "「水を飲む」の完了を取り消しました。", flash[:notice]
    assert_nil flash[:undo]
    reminder.reload
    assert_equal 2.hours.ago, reminder.last_completed_at
    assert_equal 3, reminder.completed_count
  end

  test "should undo the completion without the flash" do
    reminder = reminders(:water)
    reminder.complete!
    travel 59.minutes

    post undo_complete_reminder_url(reminder), params: { completed_at: reminder.last_completed_at.iso8601(6) }

    assert_redirected_to new_memo_url
    assert_equal "「水を飲む」の完了を取り消しました。", flash[:notice]
    reminder.reload
    assert_nil reminder.last_completed_at
    assert_equal 0, reminder.completed_count
  end

  test "should not undo the completion after UNDO_EXPIRES_IN" do
    reminder = reminders(:water)
    travel_to(2.hours.ago) { reminder.complete! }

    post undo_complete_reminder_url(reminder), params: { completed_at: reminder.last_completed_at.iso8601(6) }

    assert_redirected_to new_memo_url
    assert_equal "「水を飲む」の完了を取り消せませんでした。取り消しは完了から1時間以内に限ります。", flash[:alert]
    assert_equal 1, reminder.reload.completed_count
  end

  test "should not undo the completion with a wrong, missing or not a string completed_at" do
    reminder = reminders(:water)
    reminder.complete!

    post undo_complete_reminder_url(reminder), params: { completed_at: 1.second.ago.iso8601(6) }
    assert_predicate flash[:alert], :present?

    post undo_complete_reminder_url(reminder)
    assert_predicate flash[:alert], :present?

    post undo_complete_reminder_url(reminder), params: { completed_at: "" }
    assert_predicate flash[:alert], :present?

    post undo_complete_reminder_url(reminder), params: { completed_at: { "a" => "b" } }
    assert_predicate flash[:alert], :present?
    assert_equal 1, reminder.reload.completed_count
  end

  test "should not undo the completion already undone or completed again" do
    reminder = reminders(:water)
    post complete_reminder_url(reminder)
    completed_at = flash[:undo]["completed_at"]
    post undo_complete_reminder_url(reminder), params: { completed_at: }
    assert_equal 0, reminder.reload.completed_count

    post undo_complete_reminder_url(reminder), params: { completed_at: }
    assert_predicate flash[:alert], :present?

    travel 1.minute
    post complete_reminder_url(reminder)
    travel 1.minute
    post complete_reminder_url(reminder)
    assert_equal 2, reminder.reload.completed_count

    post undo_complete_reminder_url(reminder), params: { completed_at: }

    assert_redirected_to new_memo_url
    assert_predicate flash[:alert], :present?
    assert_equal 2, reminder.reload.completed_count
  end

  test "should not complete another user's reminder" do
    post complete_reminder_url(reminders(:others_reminder))
    assert_response :not_found
    assert_nil reminders(:others_reminder).reload.last_completed_at
  end

  test "should not undo the completion of another user's reminder" do
    other = reminders(:others_reminder)
    other.complete!

    post undo_complete_reminder_url(other), params: { completed_at: other.last_completed_at.iso8601(6) }

    assert_response :not_found
    assert_equal 1, other.reload.completed_count
  end

  test "index and show have a button to undo the completion while undoable" do
    reminder = reminders(:lunch_medicine)
    get reminders_url
    assert_select "form[action=?]", undo_complete_reminder_path(reminder), count: 0
    get reminder_url(reminder)
    assert_select "form[action=?]", undo_complete_reminder_path(reminder), count: 0

    reminder.complete!
    completed_at = reminder.last_completed_at.iso8601(6)
    get reminders_url
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(reminder)} form[action=?]", undo_complete_reminder_path(reminder) do
      assert_select "input[type=hidden][name=completed_at][value=?]", completed_at
      assert_select "button", "完了を取り消す"
    end
    get reminder_url(reminder)
    assert_select "form[action=?]", undo_complete_reminder_path(reminder) do
      assert_select "input[type=hidden][name=completed_at][value=?]", completed_at
      assert_select "button", "完了を取り消す"
    end

    travel 1.hour
    get reminders_url
    assert_select "form[action=?]", undo_complete_reminder_path(reminder), count: 0
    get reminder_url(reminder)
    assert_select "form[action=?]", undo_complete_reminder_path(reminder), count: 0
  end

  test "index and show have the buttons to complete and to undo a reminder still actionable" do
    reminder = reminders(:water)
    reminder.update!(recurrence: { "type" => "after_completion", "cooldown_minutes" => 1, "max_per_day" => 8 })
    reminder.complete!
    travel 1.minute

    get reminders_url
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(reminder)}" do
      assert_select "form[action=?]", complete_reminder_path(reminder)
      assert_select "form[action=?]", undo_complete_reminder_path(reminder)
    end
    get reminder_url(reminder)
    assert_select "form[action=?]", complete_reminder_path(reminder)
    assert_select "form[action=?]", undo_complete_reminder_path(reminder)
  end

  test "undoing from the list or the detail page goes to the new memo page" do
    reminder = reminders(:water)
    reminder.complete!
    get reminders_url
    post undo_complete_reminder_url(reminder), params: { completed_at: reminder.last_completed_at.iso8601(6) }, headers: { "Referer" => reminders_url }

    assert_redirected_to new_memo_url
    assert_equal "「水を飲む」の完了を取り消しました。", flash[:notice]
  end

  test "index and show have buttons to complete" do
    get reminders_url
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@reminder)} form[action=?] button.btn-outline-success", complete_reminder_path(@reminder), "完了"

    get reminder_url(@reminder)
    assert_select "form[action=?] button.btn-outline-success", complete_reminder_path(@reminder), "完了"
  end

  test "index and show have no button to complete a reminder that is not actionable" do
    paused = reminders(:paused)
    get reminders_url
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(paused)}"
    assert_select "form[action=?]", complete_reminder_path(paused), count: 0

    get reminder_url(paused)
    assert_response :success
    assert_select "form[action=?]", complete_reminder_path(paused), count: 0
  end
end
