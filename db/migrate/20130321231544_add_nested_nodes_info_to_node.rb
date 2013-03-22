class AddNestedNodesInfoToNode < ActiveRecord::Migration
  def up
    add_column :nodes, :nested_nodes_info, :text
  end

  def down
    remove_column :nodes, :nested_nodes_info
  end
end
