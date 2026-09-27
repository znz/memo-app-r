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

  test "prioritize_at is optional" do
    assert_nil Reminder::Status.new(state: :active).prioritize_at
  end

  test "overdue is always prioritized" do
    assert Reminder::Status.new(state: :overdue, starts_at: @now - 10.days, ends_at: @now - 1.day).prioritized?(@now)
    assert Reminder::Status.new(state: :overdue, ends_at: @now - 1.day, prioritize_at: @now + 1.day).prioritized?(@now)
  end

  test "active is prioritized from prioritize_at" do
    status = Reminder::Status.new(state: :active, starts_at: @now - 5.hours, ends_at: @now + 12.hours, prioritize_at: @now)
    assert_not status.prioritized?(@now - 1.second)
    assert status.prioritized?(@now)
    assert status.prioritized?(@now + 1.hour)
  end

  test "active without prioritize_at is not prioritized" do
    assert_not Reminder::Status.new(state: :active, starts_at: @now - 1.day, ends_at: @now + 1.minute).prioritized?(@now)
  end

  test "not actionable is not prioritized" do
    %i[waiting done cooling_down limit_reached expired disabled].each do |state|
      assert_not Reminder::Status.new(state:, prioritize_at: @now - 1.hour).prioritized?(@now), state
    end
  end
end
