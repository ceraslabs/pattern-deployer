class AddIndexContainerIdToContainers < ActiveRecord::Migration
  def change
    add_index :containers, :container_id
  end
end
