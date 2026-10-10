# frozen_string_literal: true

class CreateMemoTags < ActiveRecord::Migration[8.1]
  def up
    create_table :memo_tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :memo, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tag, type: :uuid, null: false, foreign_key: true
      t.timestamps
    end
    add_index :memo_tags, %i[memo_id tag_id], unique: true

    create_table :reminder_memo_tags, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :reminder, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tag, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :reminder_memo_tags, %i[reminder_id tag_id], unique: true

    execute <<~SQL.squish
      INSERT INTO tags (user_id, name, memo_use, created_at, updated_at)
      SELECT DISTINCT user_id, btrim(name), 'enabled', now(), now()
      FROM (
        SELECT memos.user_id, u.name FROM memos CROSS JOIN LATERAL unnest(memos.tags) AS u(name)
        UNION
        SELECT reminders.user_id, u.name FROM reminders CROSS JOIN LATERAL unnest(reminders.memo_tags) AS u(name)
      ) AS names
      WHERE btrim(name) <> ''
      ON CONFLICT (user_id, name) DO UPDATE SET memo_use = 'enabled', updated_at = now()
    SQL
    execute <<~SQL.squish
      INSERT INTO memo_tags (memo_id, tag_id, created_at, updated_at)
      SELECT DISTINCT memos.id, tags.id, now(), now()
      FROM memos CROSS JOIN LATERAL unnest(memos.tags) AS u(name)
      JOIN tags ON tags.user_id = memos.user_id AND tags.name = btrim(u.name)
    SQL
    execute <<~SQL.squish
      INSERT INTO reminder_memo_tags (reminder_id, tag_id, created_at, updated_at)
      SELECT DISTINCT reminders.id, tags.id, now(), now()
      FROM reminders CROSS JOIN LATERAL unnest(reminders.memo_tags) AS u(name)
      JOIN tags ON tags.user_id = reminders.user_id AND tags.name = btrim(u.name)
    SQL

    remove_index :memos, :tags
    remove_column :memos, :tags
    remove_column :reminders, :memo_tags
  end

  def down
    add_column :memos, :tags, :string, array: true
    add_index :memos, :tags, using: :gin
    add_column :reminders, :memo_tags, :string, array: true, null: false, default: []

    execute <<~SQL.squish
      UPDATE memos SET tags = (
        SELECT array_agg(tags.name ORDER BY tags.name)
        FROM memo_tags JOIN tags ON tags.id = memo_tags.tag_id
        WHERE memo_tags.memo_id = memos.id
      )
    SQL
    execute <<~SQL.squish
      UPDATE reminders SET memo_tags = (
        SELECT array_agg(tags.name ORDER BY tags.name)
        FROM reminder_memo_tags JOIN tags ON tags.id = reminder_memo_tags.tag_id
        WHERE reminder_memo_tags.reminder_id = reminders.id
      )
      WHERE EXISTS (SELECT 1 FROM reminder_memo_tags WHERE reminder_memo_tags.reminder_id = reminders.id)
    SQL

    drop_table :reminder_memo_tags
    drop_table :memo_tags
  end
end
