# frozen_string_literal: true

require "test_helper"

class Reminder::StatusTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.local(2026, 1, 7, 12, 0)
  end

  test "starts_at and ends_at are optional" do
    status = Reminder::Status.new(state: :disabled)
    assert_nil status.starts_at
    assert_nil status.ends_at
  end

  test "active and overdue are actionable" do
    assert Reminder::Status.new(state: :active).actionable?
    assert Reminder::Status.new(state: :overdue).actionable?
    %i[waiting done cooling_down limit_reached expired disabled].each do |state|
      assert_not Reminder::Status.new(state:).actionable?, state
    end
  end

  test "overdue is always urgent" do
    assert Reminder::Status.new(state: :overdue, starts_at: @now - 10.days, ends_at: @now - 1.day).urgent?(@now)
  end

  test "urgent within an hour" do
    assert Reminder::Status.new(state: :active, starts_at: @now - 2.hours, ends_at: @now + 1.hour).urgent?(@now)
    assert_not Reminder::Status.new(state: :active, starts_at: @now - 2.hours, ends_at: @now + 61.minutes).urgent?(@now)
  end

  test "urgent within a quarter of the window" do
    assert Reminder::Status.new(state: :active, starts_at: @now - 30.hours, ends_at: @now + 2.hours).urgent?(@now)
    assert_not Reminder::Status.new(state: :active, starts_at: @now - 2.hours, ends_at: @now + 2.hours).urgent?(@now)
  end

  test "only the one hour rule without starts_at" do
    assert_not Reminder::Status.new(state: :active, ends_at: @now + 2.hours).urgent?(@now)
    assert Reminder::Status.new(state: :active, ends_at: @now + 1.hour).urgent?(@now)
  end

  test "not urgent without ends_at" do
    assert_not Reminder::Status.new(state: :active, starts_at: @now - 1.day).urgent?(@now)
  end

  test "not actionable is not urgent" do
    assert_not Reminder::Status.new(state: :waiting, starts_at: @now + 1.minute, ends_at: @now + 30.minutes).urgent?(@now)
    assert_not Reminder::Status.new(state: :done, starts_at: @now - 1.hour, ends_at: @now + 30.minutes).urgent?(@now)
  end
end
