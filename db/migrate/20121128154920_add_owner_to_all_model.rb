class AddOwnerToAllModel < ActiveRecord::Migration
  def up
    # ALERT default value needs to be adjusted 
    add_column :containers, :user_id, :integer, :default => 3, :null => false
    add_column :credentials, :user_id, :integer, :default => 3, :null => false
    add_column :nodes, :user_id, :integer, :default => 3, :null => false
    add_column :services, :user_id, :integer, :default => 3, :null => false
    add_column :supporting_services, :user_id, :integer, :default => 3, :null => false
    add_column :templates, :user_id, :integer, :default => 3, :null => false
    add_column :topologies, :user_id, :integer, :default => 3, :null => false
    add_column :uploaded_files, :user_id, :integer, :default => 3, :null => false
  end

  def down
    remove_column :containers, :user_id
    remove_column :credentials, :user_id
    remove_column :nodes, :user_id
    remove_column :services, :user_id
    remove_column :supporting_services, :user_id
    remove_column :templates, :user_id
    remove_column :topologies, :user_id
    remove_column :uploaded_files, :user_id
  end
end
