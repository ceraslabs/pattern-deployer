class CreateUploadFileTable < ActiveRecord::Migration
  def up
    create_table :uploaded_files do |t|
      t.string :type
      t.string :war_file_id
      t.string :script_id
      t.string :identify_file_id
      t.string :key_pair_id
      t.string :for_cloud

      t.timestamps
    end
  end

  def down
    drop_table :uploaded_files
  end
end

