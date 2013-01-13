class RenameContainerToContainableInNode < ActiveRecord::Migration
  def up
    rename_column :nodes, :container_id, :containable_id
    rename_column :nodes, :container_type, :containable_type
  end

  def down
  end
end
