class RemoveContainerIdFromNodes < ActiveRecord::Migration
  def up
    remove_column :nodes, :container_id
  end

  def down
    add_column :nodes, :container_id, :integer
  end
end
