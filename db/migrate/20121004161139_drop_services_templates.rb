class DropServicesTemplates < ActiveRecord::Migration
  def up
    drop_table :services_templates
  end

  def down
  end
end
