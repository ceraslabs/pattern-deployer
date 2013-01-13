class RemoveAttrsFromServices < ActiveRecord::Migration
  def up
    remove_column :services, :attrs
  end

  def down
  end
end
