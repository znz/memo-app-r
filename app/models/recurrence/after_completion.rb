# frozen_string_literal: true

# Available again `cooldown_minutes` after the last completion (or from the beginning of the local day
# `cooldown_days` after the date of the completion), at most `max_per_day` times a day.
# Optional `due_minutes` / `due_days` give a deadline from when it became available, after which it is overdue until completed.
# It has no windows: starts_at enables it and repeat_until ends it.
class Recurrence::AfterCompletion < Recurrence::Rule
  KEYS = %w[cooldown_minutes cooldown_days due_minutes due_days max_per_day].freeze

  attr_reader :cooldown_minutes, :cooldown_days, :due_minutes, :due_days, :max_per_day

  def initialize(attributes)
    super
    raise Recurrence::InvalidRule, :missing_cooldown unless @values.key?("cooldown_minutes") || @values.key?("cooldown_days")
    raise Recurrence::InvalidRule, :cooldown_minutes_and_days if @values.key?("cooldown_minutes") && @values.key?("cooldown_days")
    raise Recurrence::InvalidRule, :due_minutes_and_days if @values.key?("due_minutes") && @values.key?("due_days")

    @cooldown_minutes = positive_integer("cooldown_minutes", :invalid_cooldown_minutes)
    @cooldown_days = positive_integer("cooldown_days", :invalid_cooldown_days)
    @due_minutes = positive_integer("due_minutes", :invalid_due_minutes)
    @due_days = positive_integer("due_days", :invalid_due_days)
    @max_per_day = positive_integer("max_per_day", :invalid_max_per_day)
  end

  def windowed? = false

  def occurrence_at_or_before(_time, anchor:) = nil

  def occurrence_after(_time, anchor:) = nil

  # cooldown_days is rounded to the beginning of the local day
  def cooldown_ends_at(completed_at)
    if cooldown_days
      completed_at.in_time_zone.beginning_of_day.advance(days: cooldown_days)
    else
      completed_at + cooldown_minutes.minutes
    end
  end

  # Exclusive end of the deadline after it became available (nil without one);
  # with due_days the available day is day 1 and the deadline is the end of day N
  def due_ends_at(became_available_at)
    if due_days
      became_available_at.in_time_zone.beginning_of_day.advance(days: due_days)
    elsif due_minutes
      became_available_at + due_minutes.minutes
    end
  end

  def label
    [
      cooldown_label,
      (I18n.t("recurrence.labels.due_minutes", minutes: due_minutes) if due_minutes),
      (I18n.t("recurrence.labels.due_days", count: due_days) if due_days),
      (I18n.t("recurrence.labels.max_per_day", count: max_per_day) if max_per_day)
    ].compact.join
  end

  private def cooldown_label
    if cooldown_days
      I18n.t("recurrence.labels.after_completion_days", count: cooldown_days)
    else
      I18n.t("recurrence.labels.after_completion", minutes: cooldown_minutes)
    end
  end
end
