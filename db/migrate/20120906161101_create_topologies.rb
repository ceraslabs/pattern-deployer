class CreateTopologies < ActiveRecord::Migration
  def change
    create_table :topologies do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
