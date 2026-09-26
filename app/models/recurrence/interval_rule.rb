# frozen_string_literal: true

# Base class of rules repeated every `interval` units from the anchor.
#
# Subclasses define
# - `occurrence(anchor, index)`: the index-th candidate (nil when the candidate does not occur)
# - `estimated_index(time, anchor)`: an index not smaller than the index of the last occurrence at or before time
# - `search_count`: how many candidates are searched (keeps every search bounded)
class Recurrence::IntervalRule < Recurrence::Rule
  KEYS = %w[interval].freeze

  attr_reader :interval

  def initialize(attributes)
    super
    @interval = positive_integer("interval", :invalid_interval, default: 1)
  end

  def windowed? = true

  def occurrence_at_or_before(time, anchor:)
    time = time.in_time_zone
    anchor = anchor.in_time_zone
    return if time < anchor

    index = estimated_index(time, anchor)
    search_count.times do
      break if index.negative?

      candidate = occurrence(anchor, index)
      return candidate if candidate && candidate >= anchor && candidate <= time

      index -= 1
    end
    nil
  end

  def occurrence_after(time, anchor:)
    time = time.in_time_zone
    anchor = anchor.in_time_zone
    index = (time < anchor) ? 0 : estimated_index(time, anchor)
    search_count.times do
      candidate = occurrence(anchor, index)
      return candidate if candidate && candidate >= anchor && candidate > time

      index += 1
    end
    nil
  end

  def label
    if interval == 1
      I18n.t(type, scope: "recurrence.labels")
    else
      I18n.t("#{type}_interval", scope: "recurrence.labels", count: interval)
    end
  end

  private def search_count = 3
end
