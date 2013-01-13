class WarFile < UploadedFile

  validates :file_name, 
            :presence => true, 
            :format => { :with => /.*\.war$/, :message => "war file must end with '.war'" }

  protected

  def get_file_dir
    Rails.configuration.war_files_dir
  end
end
