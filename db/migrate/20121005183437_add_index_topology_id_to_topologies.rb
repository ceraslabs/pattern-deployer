class AddIndexTopologyIdToTopologies < ActiveRecord::Migration
  def change
    add_index :topologies, :topology_id
  end
end
