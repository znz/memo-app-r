# frozen_string_literal: true

# Actionable reminders on the new memo page
class ReminderBoard
  Item = Data.define(:reminder, :status)

  # hidden_tag_ids: ids (strings) of the tags hidden on this device
  def initialize(reminders, now: Time.current, hidden_tag_ids: [])
    @now = now
    @hidden_tag_ids = Array(hidden_tag_ids).map(&:to_s)
    @items = reminders
      .reject { hidden?(it) }
      .map { Item.new(reminder: it, status: it.status_at(now)) }
      .select { it.status.actionable? }
  end

  def urgent = partitioned.first

  def active = partitioned.last

  # In the order of the given reminders (distance order of Reminder.near)
  def nearby = @items

  private def hidden?(reminder)
    reminder.tags.any? { !it.enabled? || @hidden_tag_ids.include?(it.id) }
  end

  private def partitioned
    @partitioned ||= @items
      .sort_by { [it.status.ends_at.nil? ? 1 : 0, it.status.ends_at.to_r, it.reminder.name] }
      .partition { it.status.urgent?(@now) }
  end
end
