class ChangeUuidDefaultToV7ForMemos < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      ALTER TABLE memos
      ALTER COLUMN id SET DEFAULT uuidv7();
    SQL
  end

  def down
    unless extension_enabled?("pgcrypto")
      raise ActiveRecord::IrreversibleMigration, <<~MESSAGE
        Enable pgcrypto again before running this migration.
      MESSAGE
    end

    execute <<~SQL
      ALTER TABLE memos
      ALTER COLUMN id SET DEFAULT gen_random_uuid();
    SQL
  end
end
