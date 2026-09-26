# frozen_string_literal: true

# Every N days
class Recurrence::Daily < Recurrence::IntervalRule
  private def occurrence(anchor, index) = anchor.advance(days: index * interval)

  private def estimated_index(time, anchor) = (time.to_date - anchor.to_date).to_i.div(interval)
end
