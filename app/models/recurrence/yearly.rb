# frozen_string_literal: true

# Every N years (February 29 falls on February 28 in common years)
class Recurrence::Yearly < Recurrence::IntervalRule
  private def occurrence(anchor, index) = anchor.advance(years: index * interval)

  private def estimated_index(time, anchor) = (time.year - anchor.year).div(interval)
end
