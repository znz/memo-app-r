# frozen_string_literal: true

# Join model of reminders and tags
class ReminderTag < ApplicationRecord
  belongs_to :reminder
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :reminder_id }
end
