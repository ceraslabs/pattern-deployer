class AddContainerNodeIdToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :container_node_id, :integer
  end
end
