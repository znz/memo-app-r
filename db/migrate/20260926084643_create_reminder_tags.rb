# frozen_string_literal: true

class CreateReminderTags < ActiveRecord::Migration[8.1]
  def change
    create_table :reminder_tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :reminder, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tag, type: :uuid, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
    add_index :reminder_tags, [:reminder_id, :tag_id], unique: true
  end
end
