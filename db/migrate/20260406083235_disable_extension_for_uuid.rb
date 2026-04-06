class DisableExtensionForUuid < ActiveRecord::Migration[7.2]
  def change
    disable_extension "pgcrypto" if extension_enabled?("pgcrypto")
  end
end
