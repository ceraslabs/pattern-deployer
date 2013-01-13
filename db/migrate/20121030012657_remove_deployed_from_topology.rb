class RemoveDeployedFromTopology < ActiveRecord::Migration
  def up
    remove_column :topologies, :deployed
  end

  def down
  end
end
