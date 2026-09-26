# frozen_string_literal: true

class AddPrioritizeAtToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :prioritize_at, :datetime
  end
end
