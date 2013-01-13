class RenameTableInheritancesToTemplateInheritances < ActiveRecord::Migration
  def up
    rename_table :inheritances, :template_inheritances
  end

  def down
    rename_table :template_inheritances, :inheritances
  end
end
