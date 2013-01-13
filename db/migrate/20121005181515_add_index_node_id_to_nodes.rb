class AddIndexNodeIdToNodes < ActiveRecord::Migration
  def change
    add_index :nodes, :node_id
  end
end
