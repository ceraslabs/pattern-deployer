class RenameNameToContainerIdInContainers < ActiveRecord::Migration
  def up
    rename_column :containers, :name, :container_id
  end

  def down
  end
end
