class AddFileContentToUploadedFiles < ActiveRecord::Migration
  def change
    add_column :uploaded_files, :file_content, :text
  end
end
