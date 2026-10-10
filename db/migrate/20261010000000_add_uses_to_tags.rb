# frozen_string_literal: true

class AddUsesToTags < ActiveRecord::Migration[8.1]
  def up
    change_table :tags, bulk: true do |t|
      t.string :memo_use, null: false, default: "unused"
      t.string :reminder_use, null: false, default: "unused"
    end
    execute "UPDATE tags SET reminder_use = CASE WHEN enabled THEN 'enabled' ELSE 'disabled' END"
    remove_column :tags, :enabled
  end

  def down
    add_column :tags, :enabled, :boolean, null: false, default: true
    execute "UPDATE tags SET enabled = (reminder_use <> 'disabled')"
    change_table :tags, bulk: true do |t|
      t.remove :memo_use, :reminder_use
    end
  end
end
