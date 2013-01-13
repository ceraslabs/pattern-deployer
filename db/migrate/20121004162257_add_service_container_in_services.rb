class AddServiceContainerInServices < ActiveRecord::Migration
  def up
    add_column :services, :service_container_id, :integer
    add_column :services, :service_container_type, :string
  end

  def down
  end
end
