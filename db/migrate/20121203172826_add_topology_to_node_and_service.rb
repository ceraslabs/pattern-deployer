class AddTopologyToNodeAndService < ActiveRecord::Migration
  def up
    add_column :nodes, :topology_id, :integer
    add_column :services, :topology_id, :integer
  end

  def down
    remove_column :nodes, :topology_id
    remove_column :services, :topology_id
  end
end
