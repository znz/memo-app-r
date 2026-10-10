# frozen_string_literal: true

# Join model of reminders and the tags of the memos they create
class ReminderMemoTag < ApplicationRecord
  belongs_to :reminder
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :reminder_id }
end
