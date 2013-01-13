class AddTopologyToTemplate < ActiveRecord::Migration
  def change
    add_column :templates, :topology_id, :integer
  end
end
