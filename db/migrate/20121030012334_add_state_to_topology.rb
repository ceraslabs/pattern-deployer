class AddStateToTopology < ActiveRecord::Migration
  def change
    add_column :topologies, :state, :integer
  end
end
