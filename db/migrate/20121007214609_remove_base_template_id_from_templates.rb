class RemoveBaseTemplateIdFromTemplates < ActiveRecord::Migration
  def up
    remove_column :templates, :base_template_id
  end

  def down
    add_column :templates, :base_template_id, :integer
  end
end
