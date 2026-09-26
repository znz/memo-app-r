# frozen_string_literal: true

require "test_helper"

class ReminderTest < ActiveSupport::TestCase
  private def at(*) = Time.zone.local(*)

  private def new_reminder(**attributes)
    Reminder.new(user: users(:one), name: "薬を飲む", recurrence: { "type" => "daily" }, starts_at: at(2026, 1, 1, 9, 0), **attributes)
  end

  test "defaults" do
    reminder = Reminder.new
    assert reminder.enabled?
    assert_equal({ "type" => "none" }, reminder.recurrence)
    assert_equal [], reminder.memo_tags
    assert_equal 200, reminder.radius_m
    assert_equal 0, reminder.completed_count
    assert_nil reminder.last_completed_at
  end

  test "valid with the minimum attributes" do
    assert new_reminder.valid?
    assert Reminder.new(user: users(:one), name: "単発").valid?
  end

  test "fixtures are valid" do
    Reminder.find_each do |reminder|
      assert reminder.valid?, "#{reminder.name}: #{reminder.errors.full_messages.to_sentence}"
    end
  end

  test "requires user" do
    reminder = new_reminder(user: nil)
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:user, :blank)
  end

  test "requires name" do
    reminder = new_reminder(name: " ")
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:name, :blank)
  end

  test "recurrence must be a valid rule" do
    reminder = new_reminder(recurrence: { "type" => "sometimes" })
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:recurrence, :unknown_type)
    assert_includes reminder.errors.full_messages.to_sentence, "sometimes"
  end

  test "windowed rule requires starts_at" do
    reminder = new_reminder(starts_at: nil)
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:starts_at, :blank)
  end

  test "none and after_completion do not require starts_at" do
    assert new_reminder(starts_at: nil, recurrence: { "type" => "none" }).valid?
    assert new_reminder(starts_at: nil, recurrence: { "type" => "after_completion", "cooldown_minutes" => 60 }).valid?
  end

  test "due_at must be after starts_at" do
    reminder = new_reminder(due_at: at(2026, 1, 1, 9, 0))
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:due_at, :after_starts_at)
    assert new_reminder(due_at: at(2026, 1, 1, 9, 1)).valid?
  end

  test "repeat_until must be after starts_at" do
    reminder = new_reminder(repeat_until: at(2025, 12, 31, 0, 0))
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:repeat_until, :after_starts_at)
    assert new_reminder(repeat_until: at(2026, 1, 10, 0, 0)).valid?
  end

  test "after_completion does not allow due_at" do
    reminder = new_reminder(recurrence: { "type" => "after_completion", "cooldown_minutes" => 60 }, due_at: at(2026, 1, 1, 12, 0))
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:due_at, :not_allowed)
  end

  test "radius_m must be positive" do
    [0, -1, nil].each do |radius_m|
      reminder = new_reminder(radius_m:)
      assert_not reminder.valid?, radius_m.inspect
      assert reminder.errors.include?(:radius_m)
    end
  end

  test "memo_tags are normalized" do
    reminder = new_reminder(memo_tags: ["薬", "", nil, "薬", "記録"])
    assert_equal %w[薬 記録], reminder.memo_tags
    assert_equal [], new_reminder(memo_tags: nil).memo_tags
  end

  test "tags must belong to the same user" do
    reminder = new_reminder(tag_ids: [tags(:work).id, tags(:other_users).id])
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:tag_ids, :not_owned)
    assert new_reminder(tag_ids: [tags(:work).id, tags(:health).id]).valid?
  end

  test "recurrence_preset assigns the preset rule" do
    reminder = new_reminder(recurrence_preset: "weekdays")
    assert reminder.valid?
    assert_equal Recurrence::PRESETS["weekdays"], reminder.recurrence
  end

  test "unknown recurrence_preset is invalid" do
    reminder = new_reminder(recurrence_preset: "sometimes")
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:recurrence_preset, :inclusion)
  end

  test "recurrence_json assigns the parsed rule and wins over the preset" do
    reminder = new_reminder(recurrence_preset: "weekdays", recurrence_json: '{"type":"monthly","nth":2,"weekday":2}')
    assert reminder.valid?
    assert_equal({ "type" => "monthly", "nth" => 2, "weekday" => 2 }, reminder.recurrence)
  end

  test "broken recurrence_json is invalid" do
    reminder = new_reminder(recurrence_json: '{"type":')
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:recurrence_json, :invalid_json)
    assert_equal({ "type" => "daily" }, reminder.recurrence)
  end

  test "blank recurrence_preset and recurrence_json keep the recurrence" do
    reminder = new_reminder(recurrence_preset: "", recurrence_json: " ")
    assert reminder.valid?
    assert_equal({ "type" => "daily" }, reminder.recurrence)
  end

  test "rule follows the recurrence" do
    reminder = new_reminder
    assert_equal "daily", reminder.rule.type
    reminder.recurrence = { "type" => "hourly", "interval" => 8 }
    assert_equal "hourly", reminder.rule.type
    reminder.recurrence["interval"] = 6
    assert_equal({ "type" => "hourly", "interval" => 6 }, reminder.rule.to_h)
  end

  test "reminder_tags reject duplicates" do
    reminder_tag = ReminderTag.new(reminder: reminders(:work_report), tag: tags(:work))
    assert_not reminder_tag.valid?
    assert reminder_tag.errors.of_kind?(:tag_id, :taken)
  end

  test "tags through reminder_tags" do
    assert_equal [tags(:work)], reminders(:work_report).tags.to_a
    assert_includes tags(:work).reminders, reminders(:work_report)
  end

  test "user has many reminders" do
    assert_includes users(:one).reminders, reminders(:lunch_medicine)
    assert_not_includes users(:one).reminders, reminders(:others_reminder)
  end

  test "enabled scope" do
    assert_includes Reminder.enabled, reminders(:lunch_medicine)
    assert_not_includes Reminder.enabled, reminders(:paused)
  end

  test "saves tags and to_param round trip" do
    reminder = new_reminder(tag_ids: [tags(:work).id])
    reminder.save!
    assert_match(/\A[#{Base58Uuid::BASE58_ALPHABET}]{22}\z/o, reminder.to_param)
    found = Reminder.find_uuid(reminder.to_param)
    assert_equal reminder, found
    assert_equal [tags(:work)], found.tags.to_a
  end

  test "schedule is built from the attributes" do
    window = reminders(:lunch_medicine).schedule.window_at(at(2026, 1, 7, 12, 0))
    assert_equal Reminder::Schedule::Window.new(starts_at: at(2026, 1, 7, 9, 0), ends_at: at(2026, 1, 7, 12, 31)), window
  end

  # status_at

  test "disabled reminder" do
    assert_equal :disabled, reminders(:paused).status_at(at(2026, 1, 7, 12, 0)).state
  end

  test "none is waiting before starts_at, active until due_at and then overdue" do
    reminder = reminders(:tax_papers)
    assert_equal :waiting, reminder.status_at(at(2026, 1, 1, 8, 59)).state
    status = reminder.status_at(at(2026, 1, 6, 18, 0, 59))
    assert_equal Reminder::Status.new(state: :active, starts_at: at(2026, 1, 1, 9, 0), ends_at: at(2026, 1, 6, 18, 1)), status
    assert_equal :overdue, reminder.status_at(at(2026, 1, 6, 18, 1)).state
  end

  test "none is done once completed" do
    reminder = reminders(:tax_papers)
    reminder.last_completed_at = at(2026, 1, 6, 20, 0)
    assert_equal :done, reminder.status_at(at(2026, 1, 7, 12, 0)).state
  end

  test "none without starts_at starts at created_at and has no end without due_at" do
    reminder = travel_to(at(2026, 1, 7, 12, 0)) { Reminder.create!(user: users(:one), name: "単発") }
    assert_equal :waiting, reminder.status_at(at(2026, 1, 7, 11, 0)).state
    assert_equal Reminder::Status.new(state: :active, starts_at: at(2026, 1, 7, 12, 0), ends_at: nil), reminder.status_at(at(2026, 1, 9, 0, 0))
  end

  test "windowed reminder is active in a window" do
    status = reminders(:lunch_medicine).status_at(at(2026, 1, 7, 12, 0))
    assert_equal Reminder::Status.new(state: :active, starts_at: at(2026, 1, 7, 9, 0), ends_at: at(2026, 1, 7, 12, 31)), status
  end

  test "windowed reminder is done when completed in the window" do
    reminder = reminders(:lunch_medicine)
    reminder.last_completed_at = at(2026, 1, 7, 9, 30)
    assert_equal :done, reminder.status_at(at(2026, 1, 7, 12, 0)).state
    reminder.last_completed_at = at(2026, 1, 6, 9, 30)
    assert_equal :active, reminder.status_at(at(2026, 1, 7, 12, 0)).state
  end

  test "windowed reminder is waiting for the next window between windows" do
    status = reminders(:lunch_medicine).status_at(at(2026, 1, 7, 13, 0))
    assert_equal Reminder::Status.new(state: :waiting, starts_at: at(2026, 1, 8, 9, 0), ends_at: at(2026, 1, 8, 12, 31)), status
    assert_equal :waiting, reminders(:second_tuesday).status_at(at(2026, 1, 7, 12, 0)).state
  end

  test "windowed reminder expires after repeat_until" do
    reminder = reminders(:recorded_show)
    assert_equal :active, reminder.status_at(at(2026, 1, 10, 23, 59, 59)).state
    assert_equal :expired, reminder.status_at(at(2026, 1, 11, 0, 0)).state
  end

  test "after_completion is active until completed" do
    status = reminders(:water).status_at(at(2026, 1, 7, 12, 0))
    assert_equal Reminder::Status.new(state: :active, starts_at: nil, ends_at: at(2026, 1, 7, 12, 0).end_of_day), status
  end

  test "after_completion without max_per_day has no end" do
    reminder = new_reminder(recurrence: { "type" => "after_completion", "cooldown_minutes" => 60 })
    assert_equal Reminder::Status.new(state: :active, starts_at: nil, ends_at: nil), reminder.status_at(at(2026, 1, 7, 12, 0))
  end

  test "after_completion is cooling down after a completion" do
    reminder = reminders(:water)
    reminder.last_completed_at = at(2026, 1, 7, 11, 30)
    reminder.completed_count = 1
    assert_equal Reminder::Status.new(state: :cooling_down, starts_at: at(2026, 1, 7, 12, 30), ends_at: nil), reminder.status_at(at(2026, 1, 7, 12, 0))
    reminder.last_completed_at = at(2026, 1, 7, 11, 0)
    assert_equal :active, reminder.status_at(at(2026, 1, 7, 12, 0)).state
  end

  test "after_completion reaches the limit of the day" do
    reminder = reminders(:water)
    reminder.last_completed_at = at(2026, 1, 7, 10, 0)
    reminder.completed_count = 8
    assert_equal Reminder::Status.new(state: :limit_reached, starts_at: at(2026, 1, 8, 0, 0), ends_at: nil), reminder.status_at(at(2026, 1, 7, 12, 0))
    assert_equal :active, reminder.status_at(at(2026, 1, 8, 0, 0)).state
  end

  test "after_completion is waiting before starts_at and expires after repeat_until" do
    reminder = reminders(:water)
    reminder.starts_at = at(2026, 1, 8, 0, 0)
    assert_equal Reminder::Status.new(state: :waiting, starts_at: at(2026, 1, 8, 0, 0), ends_at: nil), reminder.status_at(at(2026, 1, 7, 12, 0))
    reminder.starts_at = at(2026, 1, 1, 0, 0)
    reminder.repeat_until = at(2026, 1, 7, 11, 58)
    assert_equal :expired, reminder.status_at(at(2026, 1, 7, 11, 59)).state
  end

  test "after_completion ends at repeat_until when it comes first" do
    reminder = reminders(:water)
    reminder.repeat_until = at(2026, 1, 7, 17, 59)
    assert_equal at(2026, 1, 7, 18, 0), reminder.status_at(at(2026, 1, 7, 12, 0)).ends_at
  end

  test "completed_count_on counts only the completions of the day" do
    reminder = reminders(:water)
    assert_equal 0, reminder.completed_count_on(at(2026, 1, 7, 12, 0))
    reminder.last_completed_at = at(2026, 1, 7, 23, 50)
    reminder.completed_count = 3
    assert_equal 3, reminder.completed_count_on(at(2026, 1, 7, 23, 59))
    assert_equal 0, reminder.completed_count_on(at(2026, 1, 8, 0, 10))
  end

  # completion

  test "complete! counts completions and records the time" do
    reminder = reminders(:water)
    reminder.complete!(at(2026, 1, 7, 12, 0))
    reminder.complete!(at(2026, 1, 7, 13, 0))
    reminder.reload
    assert_equal 2, reminder.completed_count
    assert_equal at(2026, 1, 7, 13, 0), reminder.last_completed_at
  end

  test "complete! resets the count on another local date" do
    reminder = reminders(:water)
    reminder.complete!(at(2026, 1, 7, 23, 50))
    reminder.complete!(at(2026, 1, 8, 0, 10))
    assert_equal 1, reminder.reload.completed_count
  end

  test "complete! uses the current time by default" do
    reminder = reminders(:water)
    travel_to(at(2026, 1, 7, 12, 0)) { reminder.complete! }
    assert_equal at(2026, 1, 7, 12, 0), reminder.reload.last_completed_at
  end

  test "memo_attributes prefill a new memo" do
    assert_equal({ content: "昼の薬を飲んだ", tags: ["薬"] }, reminders(:lunch_medicine).memo_attributes)
    assert_equal({ content: "日報", tags: [] }, reminders(:work_report).memo_attributes)
  end

  test "undo_complete! restores the state before the completion" do
    reminder = reminders(:water)
    previous = Time.zone.local(2026, 1, 7, 10, 0, 5, 123456)
    reminder.update!(last_completed_at: previous, completed_count: 3)
    token = reminder.undo_token
    reminder.complete!(at(2026, 1, 7, 12, 0))
    assert reminder.undo_complete!(token)
    reminder.reload
    assert_equal previous, reminder.last_completed_at
    assert_equal 3, reminder.completed_count
  end

  test "undo_complete! restores a reminder never completed" do
    reminder = reminders(:water)
    token = reminder.undo_token
    reminder.complete!(at(2026, 1, 7, 12, 0))
    assert reminder.undo_complete!(token)
    reminder.reload
    assert_nil reminder.last_completed_at
    assert_equal 0, reminder.completed_count
  end

  test "undo token expires" do
    reminder = reminders(:water)
    travel_to(at(2026, 1, 7, 12, 0)) do
      token = reminder.undo_token
      reminder.complete!
      travel 61.minutes
      assert_not reminder.undo_complete!(token)
    end
    assert_equal 1, reminder.reload.completed_count
  end

  test "undo token of another reminder is rejected" do
    token = reminders(:github_streak).undo_token
    reminder = reminders(:water)
    reminder.complete!(at(2026, 1, 7, 12, 0))
    assert_not reminder.undo_complete!(token)
    assert_equal 1, reminder.reload.completed_count
  end

  test "tampered or blank undo token is rejected" do
    reminder = reminders(:water)
    token = reminder.undo_token
    reminder.complete!(at(2026, 1, 7, 12, 0))
    assert_not reminder.undo_complete!("#{token}x")
    assert_not reminder.undo_complete!(token.reverse)
    assert_not reminder.undo_complete!("")
    assert_not reminder.undo_complete!(nil)
    assert_equal 1, reminder.reload.completed_count
  end

  # coordinates

  test "latitude and longitude are read from lonlat" do
    reminder = reminders(:near_station)
    assert_in_delta 35.6817, reminder.latitude
    assert_in_delta 139.7671, reminder.longitude
    assert_nil reminders(:water).latitude
    assert_nil reminders(:water).longitude
  end

  test "latitude and longitude are written to lonlat" do
    reminder = new_reminder(latitude: "35.68", longitude: "139.76")
    reminder.save!
    reminder = Reminder.find(reminder.id)
    assert_in_delta 35.68, reminder.lonlat.y
    assert_in_delta 139.76, reminder.lonlat.x
  end

  test "blank latitude and longitude clear lonlat" do
    reminder = reminders(:near_station)
    reminder.update!(latitude: "", longitude: "")
    assert_nil reminder.reload.lonlat
  end

  test "latitude and longitude keep lonlat when not assigned" do
    reminder = reminders(:near_station)
    reminder.update!(name: "駅前")
    assert_in_delta 35.6817, reminder.reload.lonlat.y
  end

  test "latitude without longitude is invalid" do
    reminder = new_reminder(latitude: "35.68", longitude: "")
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:latitude, :pair)
  end

  test "coordinates out of range are invalid" do
    reminder = new_reminder(latitude: "91", longitude: "181")
    assert_not reminder.valid?
    assert reminder.errors.include?(:latitude)
    assert reminder.errors.include?(:longitude)
    reminder = new_reminder(latitude: "north", longitude: "139.76")
    assert_not reminder.valid?
    assert reminder.errors.of_kind?(:latitude, :not_a_number)
  end

  test "near returns reminders within their radius ordered by distance" do
    closer = new_reminder(name: "改札", lonlat: "POINT(139.7671 35.6813)")
    closer.save!
    reminders = Reminder.near(Memo.new(lonlat: "POINT(139.7671 35.6812)").lonlat).to_a
    assert_equal [closer, reminders(:near_station)], reminders
    assert_in_delta 11, reminders.first[:distance_m], 2
    assert_in_delta 56, reminders.last[:distance_m], 2
  end

  test "near respects the radius of each reminder" do
    reminders(:near_station).update!(radius_m: 50)
    assert_empty Reminder.near(Memo.new(lonlat: "POINT(139.7671 35.6812)").lonlat).to_a
  end

  test "near nil is empty" do
    assert_empty Reminder.near(nil).to_a
  end
end
