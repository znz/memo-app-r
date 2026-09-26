# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.string :color, null: false, default: "secondary"

      t.timestamps
    end
    add_index :tags, [:user_id, :name], unique: true
  end
end
