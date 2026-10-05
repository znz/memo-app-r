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

  test "prioritized reminders are overdue ones by ends_at, then the others by the prioritize time" do
    assert_equal %i[tax_papers start_now weigh_in lunch_medicine].map { reminders(it) }, board.prioritized.map(&:reminder)
  end

  test "prioritized reminders with the same time are sorted by name" do
    start_now = reminders(:start_now)
    users(:one).reminders.create!(name: "あとでやる", starts_at: start_now.starts_at, due_at: @now + 30.days, prioritize_at: start_now.prioritize_at)
    overdue = users(:one).reminders.create!(name: "あの書類", starts_at: @now - 2.days, due_at: reminders(:tax_papers).due_at)
    expected = [overdue.name, reminders(:tax_papers).name, "あとでやる", reminders(:start_now).name, reminders(:weigh_in).name, reminders(:lunch_medicine).name]
    assert_equal expected, names(board.prioritized)
  end

  test "reminders are prioritized from their prioritize time" do
    @now = Time.zone.local(2026, 1, 7, 6, 59)
    assert_equal %i[tax_papers start_now].map { reminders(it).name }, names(board.prioritized)
    assert_includes names(board.active), reminders(:weigh_in).name

    @now = Time.zone.local(2026, 1, 7, 11, 30)
    assert_equal %i[tax_papers start_now weigh_in].map { reminders(it).name }, names(board.prioritized)
    assert_includes names(board.active), reminders(:lunch_medicine).name

    @now = Time.zone.local(2026, 1, 7, 11, 31)
    assert_equal %i[tax_papers start_now weigh_in lunch_medicine].map { reminders(it).name }, names(board.prioritized)
  end

  test "a prioritized reminder disappears once done" do
    reminders(:weigh_in).complete!(@now - 1.hour)
    assert_not_includes names(board.prioritized + board.active), reminders(:weigh_in).name
  end

  test "an overdue windowed reminder stays prioritized after its window until completed" do
    @now = Time.zone.local(2026, 1, 7, 13, 0)
    assert_not_includes names(board.prioritized + board.active), reminders(:lunch_medicine).name

    reminders(:lunch_medicine).update!(recurrence: { "type" => "daily", "overdue" => true })
    item = board.prioritized.find { it.reminder == reminders(:lunch_medicine) }
    assert_equal :overdue, item.status.state
    assert_equal reminders(:tax_papers), board.prioritized.first.reminder

    reminders(:lunch_medicine).complete!(@now)
    assert_not_includes names(board.prioritized + board.active), reminders(:lunch_medicine).name
  end

  test "an after_completion reminder past its deadline is prioritized until completed" do
    reminders(:water).update!(recurrence: { "type" => "after_completion", "cooldown_minutes" => 60, "due_days" => 1 })
    item = board.prioritized.find { it.reminder == reminders(:water) }
    assert_equal :overdue, item.status.state

    reminders(:water).complete!(@now)
    assert_not_includes names(board.prioritized + board.active), reminders(:water).name
  end

  test "active reminders are sorted by ends_at, without ends_at last, then by name" do
    expected = %i[work_report water github_streak recorded_show far_shinjuku near_station].map { reminders(it).name }
    assert_equal expected, names(board.active)
  end

  test "items have the status" do
    item = board.prioritized.last
    assert_equal reminders(:lunch_medicine), item.reminder
    expected = Reminder::Status.new(state: :active, starts_at: Time.zone.local(2026, 1, 7, 9, 0), ends_at: Time.zone.local(2026, 1, 7, 12, 31),
      prioritize_at: Time.zone.local(2026, 1, 7, 11, 31))
    assert_equal expected, item.status
  end

  test "reminders not actionable are excluded" do
    shown = names(board.prioritized + board.active)
    %i[paused mwf_gym second_tuesday].each do |name|
      assert_not_includes shown, reminders(name).name
    end
  end

  test "reminders with a disabled tag are excluded" do
    assert_not_includes names(board.prioritized + board.active), reminders(:archived_hobby).name
  end

  test "reminders with a hidden tag are excluded" do
    board = board(hidden_tag_ids: [tags(:work).id])
    assert_not_includes names(board.active), reminders(:work_report).name
    assert_includes names(board.active), reminders(:github_streak).name
  end

  test "all_in_order has the actionable reminders in the order of the board, then the others in the given order" do
    reminders = users(:one).reminders.includes(:tags).order(:name)
    board = ReminderBoard.new(reminders, now: @now, hidden_tag_ids: [tags(:work).id], hide_by_tags: false)
    actionable = %i[tax_papers start_now weigh_in lunch_medicine work_report water github_streak archived_hobby recorded_show far_shinjuku near_station]
    others = reminders.map(&:name) & %i[paused mwf_gym second_tuesday].map { reminders(it).name }
    assert_equal actionable.map { reminders(it).name } + others, board.all_in_order.map(&:name)
  end

  test "all_in_order has a reminder done among the others in the given order" do
    reminders(:weigh_in).complete!(@now - 1.hour)
    reminders = users(:one).reminders.includes(:tags).order(:name)
    board = ReminderBoard.new(reminders, now: @now, hide_by_tags: false)
    assert_equal %i[tax_papers start_now lunch_medicine].map { reminders(it).name }, board.all_in_order.first(3).map(&:name)
    others = reminders.map(&:name) & %i[paused mwf_gym second_tuesday weigh_in].map { reminders(it).name }
    assert_equal others, board.all_in_order.last(4).map(&:name)
  end

  test "reminders with a hidden or disabled tag are on the board without hide_by_tags" do
    board = ReminderBoard.new(users(:one).reminders.includes(:tags), now: @now, hidden_tag_ids: [tags(:work).id], hide_by_tags: false)
    assert_includes names(board.active), reminders(:work_report).name
    assert_includes names(board.active), reminders(:archived_hobby).name
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
