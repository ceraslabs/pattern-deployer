class AddUploadedFileTopologyAssociation < ActiveRecord::Migration
  def up
    create_table :topologies_uploaded_files do |t|
      t.belongs_to :topology
      t.belongs_to :uploaded_file
    end

    create_table :credentials_topologies do |t|
      t.belongs_to :topology
      t.belongs_to :credential
    end
  end

  def down
    drop_table :topologies_uploaded_files
    drop_table :credentials_topologies
  end
end
