class CreateNodesTemplatesTable < ActiveRecord::Migration
  def up
    create_table :nodes_templates, :id => false do |t|
      t.references :node
      t.references :template
    end
    add_index :nodes_templates, [:node_id, :template_id]
    add_index :nodes_templates, [:template_id, :node_id]
  end

  def down
  end
end
