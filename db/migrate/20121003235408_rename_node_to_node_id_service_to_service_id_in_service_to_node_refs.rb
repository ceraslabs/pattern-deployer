class RenameNodeToNodeIdServiceToServiceIdInServiceToNodeRefs < ActiveRecord::Migration
  def up
    rename_column :service_to_node_refs, :service, :service_id
    rename_column :service_to_node_refs, :node, :node_id
  end

  def down
    rename_column :service_to_node_refs, :service_id, :service
    rename_column :service_to_node_refs, :node_id, :node
  end
end
