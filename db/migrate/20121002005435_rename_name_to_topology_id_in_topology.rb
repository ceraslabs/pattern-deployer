class RenameNameToTopologyIdInTopology < ActiveRecord::Migration
  def up
    rename_column :topologies, :name, :topology_id
  end

  def down
  end
end
