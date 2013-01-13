class ChangeToFileNameInUploadedFile < ActiveRecord::Migration
  def up
    remove_column :uploaded_files, :war_file_id
    remove_column :uploaded_files, :script_id
    remove_column :uploaded_files, :identify_file_id
    add_column :uploaded_files, :file_name, :string
  end

  def down
  end
end
