# frozen_string_literal: true

module RemindersHelper
  # "あと 2時間13分", "あと 3日4時間" or "期限切れ" (nil without ends_at)
  def remaining_time_in_words(ends_at, now:)
    return if ends_at.nil?

    remaining = (ends_at - now).to_i
    return t("reminders.remaining.overdue") unless remaining.positive?

    days, rest = remaining.divmod(1.day.to_i)
    hours, rest = rest.divmod(1.hour.to_i)
    minutes = rest / 1.minute.to_i
    if days.positive?
      t("reminders.remaining.days_hours", days:, hours:)
    elsif hours.positive?
      t("reminders.remaining.hours_minutes", hours:, minutes:)
    elsif minutes.positive?
      t("reminders.remaining.minutes", minutes:)
    else
      t("reminders.remaining.less_than_a_minute")
    end
  end

  def theme_color(color) = ThemeColor::COLORS.include?(color) ? color : "secondary"

  def theme_badge(text, color) = tag.span(text, class: "badge badge-#{theme_color(color)}")

  # Left border of a reminder card: the color of the first tag
  def card_border_color(reminder) = theme_color(reminder.tags.first&.color)

  def recurrence_label(reminder) = reminder.rule.label

  def recurrence_preset_options
    Recurrence::PRESETS.keys.map { [t("recurrence.presets.#{it}"), it] }
  end

  def theme_color_options
    ThemeColor::COLORS.map { [t("theme_colors.#{it}"), it] }
  end

  # Tags of memos and the given tags (e.g. prefilled from a reminder)
  def memo_tag_candidates(tags)
    (Memo.all_tags + Array(tags)).compact_blank.uniq.sort
  end

  def reminder_state_label(reminder, now = Time.current)
    t("reminders.states.#{reminder.status_at(now).state}")
  end
end
