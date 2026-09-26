# frozen_string_literal: true

require "test_helper"

class RemindersHelperTest < ActionView::TestCase
  setup do
    @now = Time.zone.local(2026, 1, 7, 10, 17)
  end

  test "remaining_time_in_words in hours and minutes" do
    assert_equal "あと 2時間13分", remaining_time_in_words(Time.zone.local(2026, 1, 7, 12, 30), now: @now)
    assert_equal "あと 2時間13分", remaining_time_in_words(Time.zone.local(2026, 1, 7, 12, 30), now: @now - 30.seconds)
    assert_equal "あと 1時間0分", remaining_time_in_words(@now + 1.hour, now: @now)
  end

  test "remaining_time_in_words in days and hours" do
    assert_equal "あと 3日4時間", remaining_time_in_words(@now + 3.days + 4.hours + 5.minutes, now: @now)
    assert_equal "あと 1日0時間", remaining_time_in_words(@now + 1.day, now: @now)
  end

  test "remaining_time_in_words in minutes" do
    assert_equal "あと 13分", remaining_time_in_words(@now + 13.minutes, now: @now)
    assert_equal "あと 1分未満", remaining_time_in_words(@now + 30.seconds, now: @now)
  end

  test "remaining_time_in_words after the end" do
    assert_equal "期限切れ", remaining_time_in_words(@now, now: @now)
    assert_equal "期限切れ", remaining_time_in_words(@now - 1.day, now: @now)
  end

  test "remaining_time_in_words without end" do
    assert_nil remaining_time_in_words(nil, now: @now)
  end

  test "theme_color falls back to secondary" do
    assert_equal "primary", theme_color("primary")
    assert_equal "secondary", theme_color("pink")
    assert_equal "secondary", theme_color(nil)
  end

  test "theme_badge" do
    assert_dom_equal '<span class="badge badge-primary">仕事</span>', theme_badge("仕事", "primary")
    assert_dom_equal '<span class="badge badge-secondary">&lt;b&gt;</span>', theme_badge("<b>", "pink")
  end

  test "card_border_color is the color of the first tag" do
    assert_equal "primary", card_border_color(reminders(:work_report))
    assert_equal "secondary", card_border_color(reminders(:github_streak))
  end

  test "recurrence_label" do
    assert_equal "毎週 月・火・水・木・金", recurrence_label(reminders(:work_report))
    assert_equal "完了から60分後（1日8回まで）", recurrence_label(reminders(:water))
  end

  test "recurrence_preset_options" do
    options = recurrence_preset_options
    assert_equal Recurrence::PRESETS.keys, options.map(&:last)
    assert_equal "単発", options.first.first
    assert(options.none? { it.first.include?("translation missing") })
  end

  test "theme_color_options" do
    options = theme_color_options
    assert_equal ThemeColor::COLORS, options.map(&:last)
    assert(options.none? { it.first.include?("translation missing") })
  end

  test "memo_tag_candidates adds the given tags to the tags of memos" do
    assert_equal %w[tag1 tag2 tag3 新規], memo_tag_candidates(["新規", "tag1", ""])
    assert_equal %w[tag1 tag2 tag3], memo_tag_candidates(nil)
  end

  test "reminder_state_label" do
    now = Time.zone.local(2026, 1, 7, 12, 0)
    assert_equal "期限切れ", reminder_state_label(reminders(:tax_papers), now)
    assert_equal "実行可能", reminder_state_label(reminders(:github_streak), now)
    assert_equal "無効", reminder_state_label(reminders(:paused), now)
  end

  test "every state has a label" do
    %i[waiting active done overdue cooling_down limit_reached expired disabled].each do |state|
      assert I18n.exists?("reminders.states.#{state}"), state
    end
  end
end
