# frozen_string_literal: true

# Windows of a windowed repeat rule: each occurrence opens a window which lasts
# as long as the first window (starts_at .. due_at), but ends at the next occurrence
# or at repeat_until when they come first. Without due_at a window lasts until the next occurrence.
class Reminder::Schedule
  # Half-open range [starts_at, ends_at)
  Window = Data.define(:starts_at, :ends_at) do
    def cover?(time) = starts_at <= time && (ends_at.nil? || time < ends_at)

    def length = ends_at && (ends_at - starts_at)
  end

  # The minute of due_at and repeat_until is included: 7:59 ends at 8:00 (exclusive)
  def self.exclusive_end(time) = time.change(sec: 0, usec: 0) + 1.minute

  def initialize(rule:, starts_at:, due_at:, repeat_until:)
    @rule = rule
    @starts_at = starts_at
    @due_at = due_at
    @repeat_until = repeat_until
  end

  def window_at(now)
    return unless @rule.windowed? && @starts_at && now >= @starts_at

    window = window_from(@rule.occurrence_at_or_before(now, anchor: @starts_at))
    window if window&.cover?(now)
  end

  def next_window_after(now)
    return unless @rule.windowed? && @starts_at

    window_from(@rule.occurrence_after([now, @starts_at - 1.second].max, anchor: @starts_at))
  end

  def repeat_limit
    self.class.exclusive_end(@repeat_until) if @repeat_until
  end

  private def window_from(start)
    return if start.nil? || (repeat_limit && start >= repeat_limit)

    ends_at = [@rule.occurrence_after(start, anchor: @starts_at), (start + duration if duration), repeat_limit].compact.min
    Window.new(starts_at: start, ends_at:)
  end

  private def duration
    self.class.exclusive_end(@due_at) - @starts_at if @due_at
  end
end
