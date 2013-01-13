class CreateServiceToNodeRefs < ActiveRecord::Migration
  def change
    create_table :service_to_node_refs do |t|
      t.string :ref_name
      t.integer :service
      t.integer :node

      t.timestamps
    end
  end
end
