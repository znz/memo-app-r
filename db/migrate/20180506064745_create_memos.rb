# frozen_string_literal: true

class CreateMemos < ActiveRecord::Migration[5.2]
  def change
    create_table :memos, id: :uuid do |t|
      t.string :info
      t.text :content
      t.integer :price
      t.string :category
      t.string :tags, array: true
      t.references :user, null: false
      t.inet :create_from, null: :false

      t.timestamps
    end

    add_index :memos, :tags, using: 'gin'
  end
end
