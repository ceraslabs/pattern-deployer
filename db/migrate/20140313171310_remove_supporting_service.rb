class RemoveSupportingService < ActiveRecord::Migration
  def up
    drop_table :supporting_services
  end

  def down
    create_table "supporting_services" do |t|
      t.string :name
      t.string :state
      t.integer :user_id, :default => 3, :null => false
    end
  end
end
