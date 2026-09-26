# frozen_string_literal: true

# Every N hours
class Recurrence::Hourly < Recurrence::IntervalRule
  private def occurrence(anchor, index) = anchor.advance(hours: index * interval)

  private def estimated_index(time, anchor) = ((time - anchor) / (interval * 3600)).floor
end
