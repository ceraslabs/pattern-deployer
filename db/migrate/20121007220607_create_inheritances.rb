class CreateInheritances < ActiveRecord::Migration
  def change
    create_table :inheritances do |t|
      t.integer :template_id
      t.integer :base_template_id

      t.timestamps
    end
  end
end
