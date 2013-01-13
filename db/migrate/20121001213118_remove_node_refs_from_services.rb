class RemoveNodeRefsFromServices < ActiveRecord::Migration
  def up
    remove_column :services, :node_refs
  end

  def down
    add_column :services, :node_refs, :text
  end
end
