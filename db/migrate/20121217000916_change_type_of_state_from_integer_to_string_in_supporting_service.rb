class ChangeTypeOfStateFromIntegerToStringInSupportingService < ActiveRecord::Migration
  def up
    change_column :supporting_services, :state, :string
  end

  def down
    change_column :supporting_services, :state, :integer
  end
end
