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
end
