# frozen_string_literal: true

class AddCreatedAtIndexToMemos < ActiveRecord::Migration[5.2]
  def change
    add_index :memos, :created_at
  end
end
