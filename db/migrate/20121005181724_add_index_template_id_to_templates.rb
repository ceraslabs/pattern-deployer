class AddIndexTemplateIdToTemplates < ActiveRecord::Migration
  def change
    add_index :templates, :template_id
  end
end
