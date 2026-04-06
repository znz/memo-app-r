class ChangeUuidDefaultToV7ForUsers < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      ALTER TABLE users
      ALTER COLUMN id SET DEFAULT uuidv7();
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE users
      ALTER COLUMN id SET DEFAULT gen_random_uuid();
    SQL
  end
end
