class IdentityFile < UploadedFile

  attr_accessible :key_pair_id, :for_cloud

  validates :for_cloud, :inclusion => { :in => Rails.configuration.supported_clouds, :message => "cloud %{value} is not supported" }
  validates :key_pair_id, :presence => true
  validate :key_pair_id_unique_within_cloud


  protected

  def get_file_dir
    Rails.configuration.identity_files_dir
  end

  def key_pair_id_unique_within_cloud
    self.class.all.each do |file|
      if file.id != self.id && file.for_cloud == self.for_cloud && file.key_pair_id == self.key_pair_id
        errors.add(:key_pair_id, "have already been uploaded")
      end
    end
  end
end