# frozen_string_literal: true

# State of a reminder at a time
# (waiting / active / done / overdue / cooling_down / limit_reached / expired / disabled)
Reminder::Status = Data.define(:state, :starts_at, :ends_at) do
  def initialize(state:, starts_at: nil, ends_at: nil) = super

  def actionable? = state.in?(%i[active overdue])

  # Overdue, or the rest is within URGENT_WITHIN or within URGENT_RATIO of the window
  def urgent?(now)
    return true if state == :overdue
    return false unless actionable? && ends_at

    remaining = ends_at - now
    remaining <= Reminder::URGENT_WITHIN ||
      (starts_at.present? && remaining <= (ends_at - starts_at) * Reminder::URGENT_RATIO)
  end
end
