class DropNodesServices < ActiveRecord::Migration
  def up
    drop_table :nodes_services
  end

  def down
  end
end
