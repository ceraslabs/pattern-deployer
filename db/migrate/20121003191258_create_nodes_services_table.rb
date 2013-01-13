class CreateNodesServicesTable < ActiveRecord::Migration
  def up
    create_table :nodes_services, :id => false do |t|
      t.references :node
      t.references :service
    end
    add_index :nodes_services, [:node_id, :service_id]
    add_index :nodes_services, [:service_id, :node_id]
  end

  def down
  end
end
