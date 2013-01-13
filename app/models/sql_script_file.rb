class SqlScriptFile < UploadedFile

  protected

  def get_file_dir
    Rails.configuration.sql_scripts_dir
  end
end