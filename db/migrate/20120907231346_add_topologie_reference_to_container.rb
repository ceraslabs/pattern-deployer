class AddTopologieReferenceToContainer < ActiveRecord::Migration
  def change
    add_column :containers, :topology_id, :integer
  end
end
