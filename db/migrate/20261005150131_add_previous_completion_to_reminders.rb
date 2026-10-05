# frozen_string_literal: true

class AddPreviousCompletionToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :previous_completion, :jsonb
  end
end
