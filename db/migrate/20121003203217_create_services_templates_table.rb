class CreateServicesTemplatesTable < ActiveRecord::Migration
  def up
    create_table :services_templates, :id => false do |t|
      t.references :service
      t.references :template
    end
    add_index :services_templates, [:template_id, :service_id]
    add_index :services_templates, [:service_id, :template_id]
  end

  def down
  end
end
