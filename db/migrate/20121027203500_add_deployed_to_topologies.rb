class AddDeployedToTopologies < ActiveRecord::Migration
  def change
    add_column :topologies, :deployed, :boolean
  end
end
