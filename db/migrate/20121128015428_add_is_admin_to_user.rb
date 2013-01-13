class AddIsAdminToUser < ActiveRecord::Migration
  def up
    add_column :users, :role, :string, :default => "user", :null => false
  end

  def down
    remove_column :users, :role
  end
end
