# frozen_string_literal: true

# The mod-categories master toggle used to default OFF, which silently hid
# pinned-bottom posts and the shield notifications feed on deployed sites —
# their own toggles default on but ride on the master. The default is now
# on. Only the master row is cleared: the sub-toggles always defaulted on,
# so a stored "off" there is a deliberate admin opt-out and is kept.
class EnableModCategoriesByDefault < ActiveRecord::Migration[7.2]
  SETTINGS = %w[mod_categories_enabled]

  def up
    execute(<<~SQL)
      DELETE FROM site_settings
      WHERE name IN (#{SETTINGS.map { |name| "'#{name}'" }.join(", ")})
        AND value = 'f'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
