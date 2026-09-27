# frozen_string_literal: true

# State of a reminder at a time
# (waiting / active / done / overdue / cooling_down / limit_reached / expired / disabled)
# with the time from which it is prioritized (explicit or automatic, only when actionable)
Reminder::Status = Data.define(:state, :starts_at, :ends_at, :prioritize_at) do
  def initialize(state:, starts_at: nil, ends_at: nil, prioritize_at: nil) = super

  def actionable? = state.in?(%i[active overdue])

  # Overdue, or active from prioritize_at
  def prioritized?(now) = state == :overdue || (state == :active && !prioritize_at.nil? && now >= prioritize_at)
end
