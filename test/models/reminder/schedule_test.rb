# frozen_string_literal: true

require "test_helper"

class Reminder::ScheduleTest < ActiveSupport::TestCase
  Window = Reminder::Schedule::Window

  private def at(*) = Time.zone.local(*)

  private def schedule(recurrence, starts_at:, due_at: nil, repeat_until: nil)
    Reminder::Schedule.new(rule: Recurrence.build(recurrence), starts_at:, due_at:, repeat_until:)
  end

  test "window covers a half-open range" do
    window = Window.new(starts_at: at(2026, 1, 7, 9, 0), ends_at: at(2026, 1, 7, 12, 0))
    assert_equal 3.hours, window.length
    assert window.cover?(at(2026, 1, 7, 9, 0))
    assert window.cover?(at(2026, 1, 7, 11, 59, 59))
    assert_not window.cover?(at(2026, 1, 7, 12, 0))
    assert_not window.cover?(at(2026, 1, 7, 8, 59, 59))
  end

  test "window without ends_at never ends" do
    window = Window.new(starts_at: at(2026, 1, 7, 9, 0), ends_at: nil)
    assert_nil window.length
    assert window.cover?(at(2036, 1, 7, 9, 0))
    assert_not window.cover?(at(2026, 1, 7, 8, 59))
  end

  test "rules without windows have no window" do
    [{ type: "none" }, { type: "after_completion", cooldown_minutes: 60 }].each do |recurrence|
      schedule = schedule(recurrence, starts_at: at(2026, 1, 1, 9, 0), due_at: at(2026, 1, 1, 12, 0))
      assert_nil schedule.window_at(at(2026, 1, 7, 10, 0))
      assert_nil schedule.next_window_after(at(2026, 1, 1, 0, 0))
    end
  end

  test "no window before starts_at or without starts_at" do
    assert_nil schedule({ type: "daily" }, starts_at: at(2026, 1, 5, 9, 0)).window_at(at(2026, 1, 5, 8, 59))
    assert_nil schedule({ type: "daily" }, starts_at: nil).window_at(at(2026, 1, 5, 9, 0))
    assert_nil schedule({ type: "daily" }, starts_at: nil).next_window_after(at(2026, 1, 5, 9, 0))
  end

  test "daily without due_at lasts until the next occurrence" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 1, 9, 0))
    assert_equal Window.new(starts_at: at(2026, 1, 6, 9, 0), ends_at: at(2026, 1, 7, 9, 0)), schedule.window_at(at(2026, 1, 7, 8, 0))
  end

  test "daily window ends after the minute of due_at" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 1, 9, 0), due_at: at(2026, 1, 1, 12, 30))
    assert_equal Window.new(starts_at: at(2026, 1, 7, 9, 0), ends_at: at(2026, 1, 7, 12, 31)), schedule.window_at(at(2026, 1, 7, 12, 30, 59))
    assert_nil schedule.window_at(at(2026, 1, 7, 12, 31))
    assert_nil schedule.window_at(at(2026, 1, 7, 8, 59))
  end

  test "0:00 to 23:59 includes 23:59:30" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 1, 0, 0), due_at: at(2026, 1, 1, 23, 59))
    assert_equal Window.new(starts_at: at(2026, 1, 7, 0, 0), ends_at: at(2026, 1, 8, 0, 0)), schedule.window_at(at(2026, 1, 7, 23, 59, 30))
  end

  test "every 8 hours has three windows a day" do
    schedule = schedule({ type: "hourly", interval: 8 }, starts_at: at(2026, 1, 1, 0, 0), due_at: at(2026, 1, 1, 7, 59))
    assert_equal Window.new(starts_at: at(2026, 1, 7, 0, 0), ends_at: at(2026, 1, 7, 8, 0)), schedule.window_at(at(2026, 1, 7, 7, 59, 59))
    assert_equal Window.new(starts_at: at(2026, 1, 7, 8, 0), ends_at: at(2026, 1, 7, 16, 0)), schedule.window_at(at(2026, 1, 7, 15, 59, 30))
    assert_equal Window.new(starts_at: at(2026, 1, 7, 16, 0), ends_at: at(2026, 1, 8, 0, 0)), schedule.window_at(at(2026, 1, 7, 16, 0))
  end

  test "weekly from monday 18:00 to next monday 17:59" do
    schedule = schedule({ type: "weekly" }, starts_at: at(2026, 1, 5, 18, 0), due_at: at(2026, 1, 12, 17, 59))
    assert_equal Window.new(starts_at: at(2026, 1, 5, 18, 0), ends_at: at(2026, 1, 12, 18, 0)), schedule.window_at(at(2026, 1, 12, 17, 59, 30))
    assert_equal Window.new(starts_at: at(2026, 1, 12, 18, 0), ends_at: at(2026, 1, 19, 18, 0)), schedule.window_at(at(2026, 1, 12, 18, 0))
  end

  test "weekdays have no window on saturday" do
    schedule = schedule({ type: "weekly", weekdays: [1, 2, 3, 4, 5] }, starts_at: at(2026, 1, 5, 9, 0), due_at: at(2026, 1, 5, 19, 0))
    assert_equal Window.new(starts_at: at(2026, 1, 9, 9, 0), ends_at: at(2026, 1, 9, 19, 1)), schedule.window_at(at(2026, 1, 9, 10, 0))
    assert_nil schedule.window_at(at(2026, 1, 10, 10, 0))
    assert_equal Window.new(starts_at: at(2026, 1, 12, 9, 0), ends_at: at(2026, 1, 12, 19, 1)), schedule.window_at(at(2026, 1, 12, 10, 0))
  end

  test "due_at longer than the period is capped by the next occurrence" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 1, 9, 0), due_at: at(2026, 1, 3, 9, 0))
    assert_equal Window.new(starts_at: at(2026, 1, 7, 9, 0), ends_at: at(2026, 1, 8, 9, 0)), schedule.window_at(at(2026, 1, 7, 10, 0))
  end

  test "repeat_until caps the last window and there are no windows after it" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 1, 9, 0), due_at: at(2026, 1, 1, 12, 0), repeat_until: at(2026, 1, 10, 10, 59))
    assert_equal Window.new(starts_at: at(2026, 1, 10, 9, 0), ends_at: at(2026, 1, 10, 11, 0)), schedule.window_at(at(2026, 1, 10, 10, 30))
    assert_nil schedule.window_at(at(2026, 1, 10, 11, 0))
    assert_nil schedule.window_at(at(2026, 1, 11, 9, 30))
  end

  test "next_window_after before starts_at is the first window" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 5, 9, 0), due_at: at(2026, 1, 5, 12, 0))
    assert_equal Window.new(starts_at: at(2026, 1, 5, 9, 0), ends_at: at(2026, 1, 5, 12, 1)), schedule.next_window_after(at(2026, 1, 1, 0, 0))
  end

  test "next_window_after during and between windows" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 5, 9, 0), due_at: at(2026, 1, 5, 12, 0))
    next_window = Window.new(starts_at: at(2026, 1, 8, 9, 0), ends_at: at(2026, 1, 8, 12, 1))
    assert_equal next_window, schedule.next_window_after(at(2026, 1, 7, 10, 0))
    assert_equal next_window, schedule.next_window_after(at(2026, 1, 7, 13, 0))
  end

  test "next_window_after repeat_until is nil" do
    schedule = schedule({ type: "daily" }, starts_at: at(2026, 1, 1, 9, 0), due_at: at(2026, 1, 1, 12, 0), repeat_until: at(2026, 1, 10, 10, 59))
    assert_equal Window.new(starts_at: at(2026, 1, 10, 9, 0), ends_at: at(2026, 1, 10, 11, 0)), schedule.next_window_after(at(2026, 1, 9, 10, 0))
    assert_nil schedule.next_window_after(at(2026, 1, 10, 10, 0))
    assert_nil schedule.next_window_after(at(2026, 1, 11, 0, 0))
  end
end
