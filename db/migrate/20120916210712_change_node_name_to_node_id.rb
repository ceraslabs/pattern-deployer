class ChangeNodeNameToNodeId < ActiveRecord::Migration
  def up
    rename_column :nodes, :name, :node_id
  end

  def down
  end
end
