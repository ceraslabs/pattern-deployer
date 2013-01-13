class ChangeNameToTemplateIdInTemplate < ActiveRecord::Migration
  def up
    change_table :templates do |t|
      t.rename :name, :template_id
    end
  end

  def down
  end
end
