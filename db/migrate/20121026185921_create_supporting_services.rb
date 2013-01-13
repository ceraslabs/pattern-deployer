class CreateSupportingServices < ActiveRecord::Migration
  def change
    create_table :supporting_services do |t|
      t.string :name
      t.boolean :enabled

      t.timestamps
    end
  end
end
