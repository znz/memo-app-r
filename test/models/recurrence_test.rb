# frozen_string_literal: true

require "test_helper"

class RecurrenceTest < ActiveSupport::TestCase
  private def at(*) = Time.zone.local(*)

  private def build(hash) = Recurrence.build(hash)

  private def assert_invalid_rule(error_key, hash)
    error = assert_raises(Recurrence::InvalidRule) { Recurrence.build(hash) }
    assert_equal error_key, error.error_key
    error
  end

  private def assert_quick(limit = 1.0)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, limit
  end

  # build

  test "build accepts string and symbol keys" do
    assert_equal({ "type" => "daily", "interval" => 2 }, build("type" => "daily", "interval" => 2).to_h)
    assert_equal({ "type" => "daily", "interval" => 2 }, build(type: :daily, interval: 2).to_h)
  end

  test "built rule is frozen" do
    assert_predicate build(type: "daily"), :frozen?
  end

  test "to_h keeps only the given keys" do
    assert_equal({ "type" => "weekly" }, build(type: "weekly").to_h)
    assert_equal({ "type" => "weekly", "weekdays" => [1, 3, 5] }, build(type: "weekly", weekdays: [5, 1, 3]).to_h)
  end

  test "unknown type is invalid" do
    assert_invalid_rule :unknown_type, { type: "sometimes" }
    assert_invalid_rule :unknown_type, {}
  end

  test "non hash is invalid" do
    assert_invalid_rule :not_a_hash, nil
    assert_invalid_rule :not_a_hash, [1]
  end

  test "unknown key is invalid" do
    assert_invalid_rule :unknown_key, { type: "daily", weekdays: [1] }
    assert_invalid_rule :unknown_key, { type: "none", interval: 1 }
  end

  test "interval must be a positive integer" do
    [0, -1, "2", 1.5, nil].each do |interval|
      assert_invalid_rule :invalid_interval, { type: "daily", interval: }
    end
  end

  test "error message is human readable" do
    error = assert_invalid_rule(:unknown_type, { type: "sometimes" })
    assert_includes error.message, "sometimes"
    assert_not_includes error.message, "translation missing"
  end

  # none

  test "none occurs only at the anchor" do
    rule = build(type: "none")
    anchor = at(2026, 1, 5, 9, 0)
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 5, 8, 59), anchor:)
    assert_equal anchor, rule.occurrence_at_or_before(at(2026, 1, 7, 12, 0), anchor:)
    assert_equal anchor, rule.occurrence_after(at(2026, 1, 1, 0, 0), anchor:)
    assert_nil rule.occurrence_after(anchor, anchor:)
  end

  test "none is not windowed" do
    assert_not build(type: "none").windowed?
    assert_equal "none", build(type: "none").type
  end

  test "none label" do
    assert_equal "単発", build(type: "none").label
  end

  # hourly

  test "hourly with interval 8 occurs at 0, 8 and 16 o'clock" do
    rule = build(type: "hourly", interval: 8)
    anchor = at(2026, 1, 1, 0, 0)
    assert_equal at(2026, 1, 7, 0, 0), rule.occurrence_at_or_before(at(2026, 1, 7, 7, 59, 59), anchor:)
    assert_equal at(2026, 1, 7, 8, 0), rule.occurrence_at_or_before(at(2026, 1, 7, 8, 0), anchor:)
    assert_equal at(2026, 1, 7, 16, 0), rule.occurrence_at_or_before(at(2026, 1, 7, 23, 59), anchor:)
    assert_equal at(2026, 1, 7, 16, 0), rule.occurrence_after(at(2026, 1, 7, 8, 0), anchor:)
    assert_equal at(2026, 1, 8, 0, 0), rule.occurrence_after(at(2026, 1, 7, 16, 0), anchor:)
  end

  test "hourly keeps the minutes of the anchor" do
    rule = build(type: "hourly")
    anchor = at(2026, 1, 1, 9, 30)
    assert_equal at(2026, 1, 7, 12, 30), rule.occurrence_at_or_before(at(2026, 1, 7, 12, 45), anchor:)
    assert_equal at(2026, 1, 7, 13, 30), rule.occurrence_after(at(2026, 1, 7, 12, 45), anchor:)
  end

  test "hourly before the anchor" do
    rule = build(type: "hourly")
    anchor = at(2026, 1, 1, 9, 30)
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 1, 9, 29), anchor:)
    assert_equal anchor, rule.occurrence_after(at(2025, 12, 1, 0, 0), anchor:)
  end

  test "hourly answers instantly for a 10-year-old anchor" do
    rule = build(type: "hourly")
    anchor = at(2016, 1, 1, 0, 0)
    assert_quick do
      100.times do
        assert_equal at(2026, 1, 7, 12, 0), rule.occurrence_at_or_before(at(2026, 1, 7, 12, 34), anchor:)
        assert_equal at(2026, 1, 7, 13, 0), rule.occurrence_after(at(2026, 1, 7, 12, 34), anchor:)
      end
    end
  end

  test "hourly is windowed" do
    assert build(type: "hourly").windowed?
  end

  test "hourly label" do
    assert_equal "1時間ごと", build(type: "hourly").label
    assert_equal "8時間ごと", build(type: "hourly", interval: 8).label
  end

  # daily

  test "daily with interval 2" do
    rule = build(type: "daily", interval: 2)
    anchor = at(2026, 1, 1, 9, 0)
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 1, 8, 59), anchor:)
    assert_equal anchor, rule.occurrence_at_or_before(at(2026, 1, 2, 23, 0), anchor:)
    assert_equal at(2026, 1, 3, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 4, 9, 0), anchor:)
    assert_equal at(2026, 1, 5, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 5, 9, 0), anchor:)
    assert_equal at(2026, 1, 5, 9, 0), rule.occurrence_after(at(2026, 1, 3, 9, 0), anchor:)
    assert_equal anchor, rule.occurrence_after(at(2025, 12, 31, 0, 0), anchor:)
  end

  test "daily answers instantly for a 10-year-old anchor" do
    rule = build(type: "daily")
    anchor = at(2016, 1, 1, 9, 0)
    assert_quick do
      100.times do
        assert_equal at(2026, 1, 7, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 7, 12, 0), anchor:)
        assert_equal at(2026, 1, 8, 9, 0), rule.occurrence_after(at(2026, 1, 7, 12, 0), anchor:)
      end
    end
  end

  test "daily label" do
    assert_equal "毎日", build(type: "daily").label
    assert_equal "2日ごと", build(type: "daily", interval: 2).label
  end

  # weekly

  test "weekly on weekdays" do
    rule = build(type: "weekly", weekdays: [1, 2, 3, 4, 5])
    anchor = at(2026, 1, 5, 9, 0) # Monday
    assert_equal at(2026, 1, 9, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 9, 10, 0), anchor:) # Friday
    assert_equal at(2026, 1, 9, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 10, 10, 0), anchor:) # Saturday
    assert_equal at(2026, 1, 12, 9, 0), rule.occurrence_after(at(2026, 1, 9, 9, 0), anchor:) # next Monday
    assert_equal at(2026, 1, 12, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 12, 9, 0), anchor:)
  end

  test "weekly defaults to the weekday of the anchor" do
    rule = build(type: "weekly")
    anchor = at(2026, 1, 7, 9, 0) # Wednesday
    assert_equal anchor, rule.occurrence_at_or_before(at(2026, 1, 13, 23, 0), anchor:)
    assert_equal at(2026, 1, 14, 9, 0), rule.occurrence_after(anchor, anchor:)
  end

  test "weekly on monday, wednesday and friday" do
    rule = build(type: "weekly", weekdays: [1, 3, 5])
    anchor = at(2026, 1, 5, 9, 0) # Monday
    assert_equal at(2026, 1, 7, 9, 0), rule.occurrence_after(at(2026, 1, 5, 9, 0), anchor:)
    assert_equal at(2026, 1, 9, 9, 0), rule.occurrence_after(at(2026, 1, 7, 9, 0), anchor:)
    assert_equal at(2026, 1, 12, 9, 0), rule.occurrence_after(at(2026, 1, 9, 9, 0), anchor:)
    assert_equal at(2026, 1, 7, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 8, 23, 0), anchor:)
  end

  test "weekly occurrences are not earlier than the anchor" do
    rule = build(type: "weekly", weekdays: [1, 3, 5])
    anchor = at(2026, 1, 7, 9, 0) # Wednesday
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 7, 8, 59), anchor:)
    assert_equal anchor, rule.occurrence_after(at(2026, 1, 1, 0, 0), anchor:)
    assert_equal anchor, rule.occurrence_at_or_before(at(2026, 1, 8, 12, 0), anchor:)
  end

  test "biweekly is decided by the week of the anchor" do
    rule = build(type: "weekly", interval: 2, weekdays: [1])
    anchor = at(2026, 1, 7, 9, 0) # Wednesday; Monday of this week is before the anchor
    assert_equal at(2026, 1, 19, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 2, 2, 9, 0), rule.occurrence_after(at(2026, 1, 19, 9, 0), anchor:)
    assert_equal at(2026, 1, 19, 9, 0), rule.occurrence_at_or_before(at(2026, 2, 1, 23, 0), anchor:)
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 18, 23, 0), anchor:)
  end

  test "biweekly without weekdays" do
    rule = build(type: "weekly", interval: 2)
    anchor = at(2026, 1, 5, 9, 0) # Monday
    assert_equal at(2026, 1, 19, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal anchor, rule.occurrence_at_or_before(at(2026, 1, 18, 9, 0), anchor:)
  end

  test "weekly answers instantly for a 10-year-old anchor" do
    rule = build(type: "weekly", interval: 2, weekdays: [1, 3, 5])
    anchor = at(2016, 1, 4, 9, 0) # Monday
    assert_quick do
      100.times do
        assert rule.occurrence_at_or_before(at(2026, 1, 7, 12, 0), anchor:)
        assert rule.occurrence_after(at(2026, 1, 7, 12, 0), anchor:)
      end
    end
  end

  test "weekly label" do
    assert_equal "毎週", build(type: "weekly").label
    assert_equal "毎週 月・水・金", build(type: "weekly", weekdays: [1, 3, 5]).label
    assert_equal "隔週 月曜日", build(type: "weekly", interval: 2, weekdays: [1]).label
    assert_equal "3週ごと 日曜日", build(type: "weekly", interval: 3, weekdays: [0]).label
  end

  test "weekdays must be a non-empty list of 0..6" do
    [[], [7], [-1], ["1"], 1, nil].each do |weekdays|
      assert_invalid_rule :invalid_weekdays, { type: "weekly", weekdays: }
    end
  end

  # monthly

  test "monthly day 31 is clamped to the end of the month" do
    rule = build(type: "monthly", day: 31)
    anchor = at(2026, 1, 31, 9, 0)
    assert_equal at(2026, 2, 28, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 3, 31, 9, 0), rule.occurrence_after(at(2026, 2, 28, 9, 0), anchor:)
    assert_equal at(2026, 2, 28, 9, 0), rule.occurrence_at_or_before(at(2026, 3, 30, 0, 0), anchor:)
  end

  test "monthly defaults to the day of the anchor" do
    rule = build(type: "monthly")
    anchor = at(2026, 1, 31, 9, 0)
    assert_equal at(2026, 2, 28, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 3, 31, 9, 0), rule.occurrence_after(at(2026, 2, 28, 9, 0), anchor:)
  end

  test "monthly day -1 is the last day of the month" do
    rule = build(type: "monthly", day: -1)
    anchor = at(2026, 1, 1, 9, 0)
    assert_equal at(2026, 1, 31, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 2, 28, 9, 0), rule.occurrence_after(at(2026, 1, 31, 9, 0), anchor:)
    assert_equal at(2026, 1, 31, 9, 0), rule.occurrence_at_or_before(at(2026, 2, 27, 0, 0), anchor:)
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 30, 0, 0), anchor:)
  end

  test "monthly on the second tuesday" do
    rule = build(type: "monthly", nth: 2, weekday: 2)
    anchor = at(2026, 1, 1, 10, 0)
    assert_equal at(2026, 1, 13, 10, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 2, 10, 10, 0), rule.occurrence_after(at(2026, 1, 13, 10, 0), anchor:)
    assert_equal at(2026, 2, 10, 10, 0), rule.occurrence_at_or_before(at(2026, 3, 9, 0, 0), anchor:)
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 12, 0, 0), anchor:)
  end

  test "monthly on the last wednesday" do
    rule = build(type: "monthly", nth: -1, weekday: 3)
    anchor = at(2026, 1, 1, 9, 0)
    assert_equal at(2026, 1, 28, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 2, 25, 9, 0), rule.occurrence_after(at(2026, 1, 28, 9, 0), anchor:)
    assert_equal at(2026, 3, 25, 9, 0), rule.occurrence_after(at(2026, 2, 25, 9, 0), anchor:)
  end

  test "monthly on the last business day" do
    rule = build(type: "monthly", nth: -1, weekday: "business")
    anchor = at(2026, 1, 1, 9, 0)
    assert_equal at(2026, 1, 30, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 2, 27, 9, 0), rule.occurrence_after(at(2026, 1, 30, 9, 0), anchor:)
    assert_equal at(2026, 3, 31, 9, 0), rule.occurrence_after(at(2026, 2, 27, 9, 0), anchor:)
    assert_equal at(2026, 5, 29, 9, 0), rule.occurrence_at_or_before(at(2026, 6, 29, 0, 0), anchor:)
  end

  test "monthly on the first business day" do
    rule = build(type: "monthly", nth: 1, weekday: "business")
    anchor = at(2026, 1, 1, 9, 0)
    assert_equal anchor, rule.occurrence_at_or_before(anchor, anchor:)
    assert_equal at(2026, 2, 2, 9, 0), rule.occurrence_after(anchor, anchor:)
  end

  test "monthly skips months without the fifth weekday" do
    rule = build(type: "monthly", nth: 5, weekday: 2)
    anchor = at(2026, 1, 1, 9, 0)
    assert_equal at(2026, 3, 31, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_nil rule.occurrence_at_or_before(at(2026, 3, 30, 0, 0), anchor:)
  end

  test "monthly with interval 3" do
    rule = build(type: "monthly", interval: 3, day: 15)
    anchor = at(2026, 1, 15, 9, 0)
    assert_equal at(2026, 4, 15, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 4, 15, 9, 0), rule.occurrence_at_or_before(at(2026, 6, 30, 0, 0), anchor:)
    assert_equal at(2026, 7, 15, 9, 0), rule.occurrence_after(at(2026, 4, 15, 9, 0), anchor:)
  end

  test "monthly occurrence before the anchor in the first month is skipped" do
    rule = build(type: "monthly", day: 15)
    anchor = at(2026, 1, 20, 9, 0)
    assert_equal at(2026, 2, 15, 9, 0), rule.occurrence_after(at(2026, 1, 1, 0, 0), anchor:)
    assert_nil rule.occurrence_at_or_before(at(2026, 2, 1, 0, 0), anchor:)
  end

  test "monthly answers instantly for a 10-year-old anchor" do
    rule = build(type: "monthly", nth: 5, weekday: 2)
    anchor = at(2016, 1, 1, 9, 0)
    assert_quick do
      100.times do
        assert_equal at(2025, 12, 30, 9, 0), rule.occurrence_at_or_before(at(2026, 1, 7, 12, 0), anchor:)
        assert_equal at(2026, 3, 31, 9, 0), rule.occurrence_after(at(2026, 1, 7, 12, 0), anchor:)
      end
    end
  end

  test "monthly label" do
    assert_equal "毎月", build(type: "monthly").label
    assert_equal "毎月 15日", build(type: "monthly", day: 15).label
    assert_equal "毎月 末日", build(type: "monthly", day: -1).label
    assert_equal "毎月 第2火曜日", build(type: "monthly", nth: 2, weekday: 2).label
    assert_equal "毎月 最終水曜日", build(type: "monthly", nth: -1, weekday: 3).label
    assert_equal "毎月 最終平日", build(type: "monthly", nth: -1, weekday: "business").label
    assert_equal "毎月 第1平日", build(type: "monthly", nth: 1, weekday: "business").label
    assert_equal "3か月ごと 15日", build(type: "monthly", interval: 3, day: 15).label
  end

  test "monthly validations" do
    [0, 32, -2, "15"].each do |day|
      assert_invalid_rule :invalid_day, { type: "monthly", day: }
    end
    assert_invalid_rule :day_and_nth, { type: "monthly", day: 15, nth: 2, weekday: 2 }
    [0, 6, -2, "2"].each do |nth|
      assert_invalid_rule :invalid_nth, { type: "monthly", nth:, weekday: 2 }
    end
    [7, -1, "holiday", "2"].each do |weekday|
      assert_invalid_rule :invalid_weekday, { type: "monthly", nth: 2, weekday: }
    end
    assert_invalid_rule :invalid_weekday, { type: "monthly", nth: 2 }
    assert_invalid_rule :invalid_nth, { type: "monthly", weekday: 2 }
  end

  # yearly

  test "yearly clamps february 29 to february 28 in common years" do
    rule = build(type: "yearly")
    anchor = at(2024, 2, 29, 9, 0)
    assert_equal at(2025, 2, 28, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal at(2026, 2, 28, 9, 0), rule.occurrence_after(at(2025, 2, 28, 9, 0), anchor:)
    assert_equal at(2028, 2, 29, 9, 0), rule.occurrence_at_or_before(at(2028, 3, 1, 0, 0), anchor:)
    assert_equal at(2027, 2, 28, 9, 0), rule.occurrence_at_or_before(at(2028, 2, 28, 23, 0), anchor:)
    assert_nil rule.occurrence_at_or_before(at(2024, 2, 29, 8, 0), anchor:)
  end

  test "yearly with interval 2" do
    rule = build(type: "yearly", interval: 2)
    anchor = at(2026, 1, 7, 9, 0)
    assert_equal at(2028, 1, 7, 9, 0), rule.occurrence_after(anchor, anchor:)
    assert_equal anchor, rule.occurrence_at_or_before(at(2028, 1, 7, 8, 0), anchor:)
  end

  test "yearly label" do
    assert_equal "毎年", build(type: "yearly").label
    assert_equal "2年ごと", build(type: "yearly", interval: 2).label
  end

  # after_completion

  test "after_completion is not windowed" do
    rule = build(type: "after_completion", cooldown_minutes: 60, max_per_day: 5)
    anchor = at(2026, 1, 1, 9, 0)
    assert_not rule.windowed?
    assert_equal 60, rule.cooldown_minutes
    assert_equal 5, rule.max_per_day
    assert_nil rule.occurrence_at_or_before(at(2026, 1, 7, 12, 0), anchor:)
    assert_nil rule.occurrence_after(at(2026, 1, 7, 12, 0), anchor:)
  end

  test "after_completion max_per_day is optional" do
    rule = build("type" => "after_completion", "cooldown_minutes" => 60)
    assert_nil rule.max_per_day
    assert_equal({ "type" => "after_completion", "cooldown_minutes" => 60 }, rule.to_h)
  end

  test "after_completion validations" do
    assert_invalid_rule :invalid_cooldown_minutes, { type: "after_completion" }
    assert_invalid_rule :invalid_cooldown_minutes, { type: "after_completion", cooldown_minutes: 0 }
    assert_invalid_rule :invalid_max_per_day, { type: "after_completion", cooldown_minutes: 60, max_per_day: 0 }
    assert_invalid_rule :unknown_key, { type: "after_completion", cooldown_minutes: 60, interval: 1 }
  end

  test "after_completion label" do
    assert_equal "完了から60分後", build(type: "after_completion", cooldown_minutes: 60).label
    assert_equal "完了から60分後（1日5回まで）", build(type: "after_completion", cooldown_minutes: 60, max_per_day: 5).label
  end

  # presets

  test "presets are ordered and valid" do
    assert_equal %w[none hourly every_6_hours every_8_hours daily weekdays weekly biweekly monthly monthly_last_wednesday yearly after_1_hour after_1_hour_5_per_day],
      Recurrence::PRESETS.keys
    Recurrence::PRESETS.each do |key, hash|
      assert_equal hash, build(hash).to_h, key
    end
  end
end
