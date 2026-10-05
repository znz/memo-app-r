# frozen_string_literal: true

# Actionable reminders on the new memo page
class ReminderBoard
  Item = Data.define(:reminder, :status)

  # hidden_tag_ids: ids (strings) of the tags hidden on this device
  # hide_by_tags: false keeps the reminders with a disabled or hidden tag (for the list of all the reminders)
  def initialize(reminders, now: Time.current, hidden_tag_ids: [], hide_by_tags: true)
    @now = now
    @hidden_tag_ids = Array(hidden_tag_ids).map(&:to_s)
    @reminders = reminders.to_a
    @items = @reminders
      .reject { hide_by_tags && hidden?(it) }
      .map { Item.new(reminder: it, status: it.status_at(now)) }
      .select { it.status.actionable? }
  end

  # Overdue ones by ends_at, then the others by the prioritize time, each then by name
  def prioritized
    @prioritized ||= partitioned.first.sort_by do |item|
      status = item.status
      overdue = status.state == :overdue
      [overdue ? 0 : 1, (overdue ? status.ends_at : status.prioritize_at).to_r, item.reminder.name]
    end
  end

  # By ends_at, without ends_at last, then by name
  def active
    @active ||= partitioned.last.sort_by { [it.status.ends_at.nil? ? 1 : 0, it.status.ends_at.to_r, it.reminder.name] }
  end

  # In the order of the given reminders (distance order of Reminder.near)
  def nearby = @items

  # All the given reminders: the actionable ones as on the new memo page (prioritized, then active),
  # then the others in the given order
  def all_in_order
    actionable = (prioritized + active).map(&:reminder)
    actionable + (@reminders - actionable)
  end

  private def hidden?(reminder)
    reminder.tags.any? { !it.enabled? || @hidden_tag_ids.include?(it.id) }
  end

  private def partitioned
    @partitioned ||= @items.partition { it.status.prioritized?(@now) }
  end
end
