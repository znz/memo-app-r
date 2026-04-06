# frozen_string_literal: true

class ChangeUuidDefaultToV7ForMemos < ActiveRecord::Migration[7.2]
  def up
    unless select_value("SELECT to_regprocedure('uuidv7()')")
      raise "uuidv7() function is not available in this PostgreSQL installation. " \
            "Ensure you are using PostgreSQL 17+ or install the pg_uuidv7 extension."
    end

    execute <<~SQL.squish
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

    execute <<~SQL.squish
      ALTER TABLE memos
      ALTER COLUMN id SET DEFAULT gen_random_uuid();
    SQL
  end
end
