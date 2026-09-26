# frozen_string_literal: true

# Every N weeks on the given weekdays (0 = Sunday .. 6 = Saturday, default: the weekday of the anchor).
# Weeks start on Monday and are counted from the week of the anchor.
class Recurrence::Weekly < Recurrence::IntervalRule
  KEYS = %w[interval weekdays].freeze

  attr_reader :weekdays

  def initialize(attributes)
    super
    return unless @values.key?("weekdays")

    weekdays = @values["weekdays"]
    unless weekdays.is_a?(Array) && weekdays.present? && weekdays.all? { it.is_a?(Integer) && (0..6).cover?(it) }
      raise Recurrence::InvalidRule, :invalid_weekdays
    end

    @weekdays = @values["weekdays"] = weekdays.uniq.sort
  end

  def label
    base = (interval == 2) ? I18n.t("recurrence.labels.biweekly") : super
    with_detail(base, weekdays_label)
  end

  private def weekdays_label
    if weekdays.nil?
      nil
    elsif weekdays.one?
      I18n.t("date.day_names")[weekdays.first]
    else
      weekdays.map { I18n.t("date.abbr_day_names")[it] }.join(I18n.t("recurrence.labels.weekday_separator"))
    end
  end

  # Candidates are days from the anchor
  private def occurrence(anchor, index)
    candidate = anchor.advance(days: index)
    candidate if (weekdays || [anchor.wday]).include?(candidate.wday) &&
      weeks_between(anchor.to_date, candidate.to_date).modulo(interval).zero?
  end

  private def estimated_index(time, anchor) = (time.to_date - anchor.to_date).to_i

  private def search_count = 7 * interval + 7

  private def weeks_between(from, to)
    (to.beginning_of_week(:monday) - from.beginning_of_week(:monday)).to_i / 7
  end
end
