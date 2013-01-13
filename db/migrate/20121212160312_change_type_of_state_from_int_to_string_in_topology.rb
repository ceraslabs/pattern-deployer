class ChangeTypeOfStateFromIntToStringInTopology < ActiveRecord::Migration
  def up
    change_column :topologies, :state, :string
  end

  def down
    change_column :topologies, :state, :integer
  end
end
