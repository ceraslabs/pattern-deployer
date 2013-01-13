class AddTopologyToNode < ActiveRecord::Migration
  def change
    add_column :nodes, :topology_id, :integer
  end
end
