class AddContainerTypeToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :container_type, :string
  end
end
