# frozen_string_literal: true

class CreateMemos < ActiveRecord::Migration[5.2]
  def change
    create_table :memos, id: :uuid do |t|
      t.string :info
      t.text :content
      t.integer :price
      t.string :category
      t.string :tags, array: true
      t.uuid :user_id, null: false, index: true
      t.inet :create_from, null: false
      t.st_point :lonlat, geographic: true

      t.timestamps
    end

    add_index :memos, :tags, using: 'gin'
    add_index :memos, :lonlat, using: 'gist'
  end
end
