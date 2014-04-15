class RemoveContainerNodeFromNodes < ActiveRecord::Migration
  def up
    remove_column :nodes, :container_node_id
  end

  def down
    add_column :nodes, :container_node_id, :integer
  end
end
