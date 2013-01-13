class RemoveFileContentFromUploadedFile < ActiveRecord::Migration
  def up
    remove_column :uploaded_files, :file_content
  end

  def down
  end
end
