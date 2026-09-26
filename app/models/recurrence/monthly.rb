# frozen_string_literal: true

# Every N months on a day (1..31, -1 = last day, clamped to the end of the month)
# or on the nth (1..5, -1 = last) weekday (0..6 or "business" = Monday to Friday).
# Without day and nth, the day of the anchor is used. Months without the nth weekday are skipped.
class Recurrence::Monthly < Recurrence::IntervalRule
  KEYS = %w[interval day nth weekday].freeze
  BUSINESS = "business"
  DAYS = [-1, *1..31].freeze
  NTHS = [-1, *1..5].freeze
  WEEKDAYS = [*0..6, BUSINESS].freeze

  attr_reader :day, :nth, :weekday

  def initialize(attributes)
    super
    if @values.key?("day")
      raise Recurrence::InvalidRule, :day_and_nth if @values.key?("nth") || @values.key?("weekday")

      @day = allowed_value("day", DAYS, :invalid_day)
    elsif @values.key?("nth") || @values.key?("weekday")
      @nth = allowed_value("nth", NTHS, :invalid_nth)
      @weekday = allowed_value("weekday", WEEKDAYS, :invalid_weekday)
    end
  end

  def label
    with_detail(super, day_label || nth_label)
  end

  private def allowed_value(key, values, error_key)
    value = @values[key]
    raise Recurrence::InvalidRule, error_key unless values.any? { it.eql?(value) }

    value
  end

  # Candidates are months from the anchor, searched up to `interval * 2 + 12` months
  private def estimated_index(time, anchor) = ((time.year - anchor.year) * 12 + time.month - anchor.month).div(interval)

  private def search_count = (interval * 2 + 12).div(interval) + 1

  private def occurrence(anchor, index)
    month = anchor.advance(months: index * interval)
    day_of_month = nth ? nth_day(month.to_date) : clamped_day(month.to_date, day || anchor.day)
    month.change(day: day_of_month) if day_of_month
  end

  private def clamped_day(date, day)
    last_day = date.end_of_month.day
    (day == -1) ? last_day : [day, last_day].min
  end

  private def nth_day(date)
    days = (1..date.end_of_month.day).select { weekday_matches?(date.change(day: it)) }
    (nth == -1) ? days.last : days[nth - 1]
  end

  private def weekday_matches?(date)
    (weekday == BUSINESS) ? (1..5).cover?(date.wday) : date.wday == weekday
  end

  private def day_label
    return unless day

    (day == -1) ? I18n.t("recurrence.labels.last_day") : I18n.t("recurrence.labels.day", day:)
  end

  private def nth_label
    return unless nth

    weekday_name = (weekday == BUSINESS) ? I18n.t("recurrence.labels.business_day") : I18n.t("date.day_names")[weekday]
    (nth == -1) ? I18n.t("recurrence.labels.last_weekday", weekday: weekday_name) : I18n.t("recurrence.labels.nth_weekday", nth:, weekday: weekday_name)
  end
end
