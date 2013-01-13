require "chef/cookbook_uploader"
require "chef/knife"
require "chef/knife/cookbook_upload"
require "chef/shef/ext"
require "fileutils"

class ChefCookbookWrapper

  @@cookbook_files_backup_folder = "/tmp/"

  def initialize(name)
    @name = name
  end

  def self.create(name)
    cookbook_path = [Rails.configuration.chef_repo_dir, "cookbooks", name].join("/")
    if File.directory?(cookbook_path)
      cookbook = new(name)
      Chef::Config.from_file(Rails.configuration.chef_config_file)
      Shef::Extensions.extend_context_object(cookbook)

      return cookbook
    else
      return nil
    end
  end

  def add_cookbook_file(file_name, file)
    existing_file = get_cookbook_file(file_name)
    if existing_file.nil? || !FileUtils.compare_file(file, existing_file)
      destination = get_cookbook_file_folder
      FileUtils.cp(file, destination)
    end
  end

  def get_cookbook_file(file_name)
    file_path = [get_cookbook_file_folder, file_name].join("/")
    if File.exists?(file_path)
      return file_path
    else
      return nil
    end
  end

  def get_cookbook_file_folder
    [Rails.application.config.chef_repo_dir, "cookbooks", @name, "files", "default"].join("/")
  end

  def save
    uploader = Chef::Knife::CookbookUpload.new
    uploader.name_args = [@name]
    uploader.config[:cookbook_path] = "#{Rails.application.config.chef_repo_dir}/cookbooks"
    uploader.run
  end

  private_class_method :new
end