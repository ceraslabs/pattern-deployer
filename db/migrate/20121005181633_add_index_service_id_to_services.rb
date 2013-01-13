class AddIndexServiceIdToServices < ActiveRecord::Migration
  def change
    add_index :services, :service_id
  end
end
