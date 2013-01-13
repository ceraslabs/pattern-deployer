class RenameContainablToParentInNode < ActiveRecord::Migration
  def up
    rename_column :nodes, :containable_id, :parent_id
    rename_column :nodes, :containable_type, :parent_type
  end

  def down
    rename_column :nodes, :parent_id, :containable_id
    rename_column :nodes, :parent_type, :containable_type
  end
end
