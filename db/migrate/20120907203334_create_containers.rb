class CreateContainers < ActiveRecord::Migration
  def change
    create_table :containers do |t|
      t.string :name
      t.integer :num_of_copies

      t.timestamps
    end
  end
end
