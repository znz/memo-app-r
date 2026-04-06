# frozen_string_literal: true

class DisableExtensionForUuid < ActiveRecord::Migration[7.2]
  def up
    return unless extension_enabled?("pgcrypto")
    if pgcrypto_still_required?
      raise ActiveRecord::IrreversibleMigration, <<~MESSAGE
        Cannot disable pgcrypto while column defaults still reference gen_random_uuid().
        Remove or update those defaults before running this migration.
      MESSAGE
    end
    disable_extension "pgcrypto"
  end

  def down
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
  end

  private def pgcrypto_still_required?
    select_value(<<~SQL.squish).to_i.positive?
      SELECT COUNT(*)
      FROM pg_attrdef d
      INNER JOIN pg_class c ON c.oid = d.adrelid
      INNER JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE pg_get_expr(d.adbin, d.adrelid) LIKE '%gen_random_uuid()%'
        AND c.relkind IN ('r', 'p')
        AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    SQL
  end
end
