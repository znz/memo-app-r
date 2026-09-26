# frozen_string_literal: true

class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :memo_template
      t.string :memo_tags, array: true, null: false, default: []
      t.boolean :enabled, null: false, default: true
      t.datetime :starts_at
      t.datetime :due_at
      t.datetime :repeat_until
      t.jsonb :recurrence, null: false, default: { type: "none" }
      t.st_point :lonlat, geographic: true
      t.integer :radius_m, null: false, default: 200
      t.datetime :last_completed_at
      t.integer :completed_count, null: false, default: 0

      t.timestamps
    end
    add_index :reminders, :lonlat, using: :gist
  end
end
