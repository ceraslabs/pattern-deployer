class ChangeEnabledToStateInSupportingService < ActiveRecord::Migration
  def up
    remove_column :supporting_services, :enabled
    add_column :supporting_services, :state, :integer
  end

  def down
  end
end
