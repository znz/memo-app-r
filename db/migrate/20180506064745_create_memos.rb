# frozen_string_literal: true

class CreateMemos < ActiveRecord::Migration[5.2]
  def change
    create_table :memos, id: :uuid do |t|
      t.string :info
      t.text :content
      t.integer :price
      t.string :category
      t.string :tags
      t.uuid :user_id
      t.inet :create_from

      t.timestamps
    end
  end
end
