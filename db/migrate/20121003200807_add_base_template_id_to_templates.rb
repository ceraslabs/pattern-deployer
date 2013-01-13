class AddBaseTemplateIdToTemplates < ActiveRecord::Migration
  def change
    add_column :templates, :base_template_id, :integer
  end
end
