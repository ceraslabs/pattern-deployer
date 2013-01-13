class AddContainerToNode < ActiveRecord::Migration
  def change
    add_column :nodes, :container_id, :integer
  end
end
