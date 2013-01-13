class RedefineService < ActiveRecord::Migration
  def up
    rename_column :services, :definition, :properties
    rename_column :services, :name, :service_id
    add_column :services, :node_refs, :text
  end

  def down
  end
end
