# frozen_string_literal: true

require "test_helper"

class ReminderBoardTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.local(2026, 1, 7, 12, 0)
  end

  private def board(reminders = users(:one).reminders.includes(:tags), hidden_tag_ids: [])
    ReminderBoard.new(reminders, now: @now, hidden_tag_ids:)
  end

  private def names(items) = items.map { it.reminder.name }

  test "urgent reminders are sorted by ends_at" do
    assert_equal [reminders(:tax_papers), reminders(:lunch_medicine)], board.urgent.map(&:reminder)
  end

  test "active reminders are sorted by ends_at, without ends_at last, then by name" do
    expected = %i[work_report water github_streak recorded_show far_shinjuku near_station].map { reminders(it).name }
    assert_equal expected, names(board.active)
  end

  test "items have the status" do
    item = board.urgent.last
    assert_equal reminders(:lunch_medicine), item.reminder
    assert_equal Reminder::Status.new(state: :active, starts_at: Time.zone.local(2026, 1, 7, 9, 0), ends_at: Time.zone.local(2026, 1, 7, 12, 31)), item.status
  end

  test "reminders not actionable are excluded" do
    shown = names(board.urgent + board.active)
    %i[paused mwf_gym second_tuesday].each do |name|
      assert_not_includes shown, reminders(name).name
    end
  end

  test "reminders with a disabled tag are excluded" do
    assert_not_includes names(board.urgent + board.active), reminders(:archived_hobby).name
  end

  test "reminders with a hidden tag are excluded" do
    board = board(hidden_tag_ids: [tags(:work).id])
    assert_not_includes names(board.active), reminders(:work_report).name
    assert_includes names(board.active), reminders(:github_streak).name
  end

  test "nearby keeps the order of the relation and only actionable reminders" do
    point = Memo.new(lonlat: "POINT(139.7671 35.6812)").lonlat
    closer = users(:one).reminders.create!(name: "改札", lonlat: "POINT(139.7671 35.6813)", starts_at: @now - 1.day)
    board = board(users(:one).reminders.near(point).includes(:tags))
    assert_equal [closer, reminders(:near_station)], board.nearby.map(&:reminder)

    closer.update!(last_completed_at: @now - 1.minute)
    assert_equal [reminders(:near_station)], board(users(:one).reminders.near(point)).nearby.map(&:reminder)
  end
end
