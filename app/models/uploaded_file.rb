class UploadedFile < ActiveRecord::Base

  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :uploaded_files

  attr_accessible :file_name, :id, :owner

  validates :file_name, :presence => true
  validates_presence_of :owner
  validate :file_name_unique_within_same_type

  after_save :commit_file
  after_destroy :delete_file


  def upload(file_io)
    write_to_disk(file_io)
    @dirty = true
  end

  def reupload(file_io)
    write_to_disk(file_io)
    @dirty = true
    self.save!
  end

  def rename(new_name)
    old_path = get_file_path
    temp_path = [get_temp_dir, new_name].join("/")
    FileUtils.mv(old_path, temp_path)

    begin
      self.file_name = new_name
      @dirty = true
      self.save!
    rescue Exception => ex
      FileUtils.mv(temp_path, old_path) if File.exists?(temp_path)
      raise
    end
  end

  def get_file_type
    if self.class == IdentityFile
      return "identity_file"
    elsif self.class == WarFile
      return "war_file"
    elsif self.class == SqlScriptFile
      return "sql_script_file"
    end
  end

  def get_file_path
    [self.get_file_dir, self.file_name].join("/")
  end


  protected

  def get_file_dir
    raise "Not implemented"
  end

  def commit_file
    if @dirty
      file_dir = get_file_dir
      FileUtils.mkdir_p(file_dir) unless File.directory?(file_dir)
      FileUtils.mv("#{get_temp_dir}/#{file_name}", get_file_path)
      @dirty = false
    end
  end

  def delete_file
    FileUtils.rm(get_file_path) if File.exists?(get_file_path)
  end

  def write_to_disk(file_io)
    File.open("#{get_temp_dir}/#{file_name}", "w") do |out|
      out.write(file_io.read)
    end
  end

  def get_temp_dir
    "/tmp"
  end

  def file_name_unique_within_same_type
    UploadedFile.all.each do |file|
      if file.id != self.id && file.instance_of?(self.class) && file.file_name == self.file_name
        errors.add(:file_name, "have already been taken")
      end
    end
  end
end