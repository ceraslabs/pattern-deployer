class RenameFromTopologyIdToContainerIdInNodes < ActiveRecord::Migration
  def up
    rename_column :nodes, :topology_id, :container_id
  end

  def down
  end
end
