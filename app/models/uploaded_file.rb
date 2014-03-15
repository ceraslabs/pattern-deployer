#
# Copyright 2013 Marin Litoiu, Hongbin Lu, Mark Shtern, Bradlley Simmons, Mike
# Smit
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require "pattern_deployer"

class UploadedFile < ActiveRecord::Base

  include PatternDeployer::Errors
  Cookbook = PatternDeployer::Chef::ChefCookbookWrapper

  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :uploaded_files
  has_and_belongs_to_many :topologies

  attr_accessible :file_name, :id, :owner

  validates :file_name, :presence => true
  validates_presence_of :owner
  validate :file_name_unique

  before_destroy :file_mutable
  before_destroy :delete_cookbook_files
  before_save :file_mutable
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

  def unlock(&block)
    begin
      self.class.skip_callback(:save, :before, :file_mutable)
      yield
    ensure
      self.class.set_callback(:save, :before, :file_mutable)
    end
  end


  protected

  def get_file_dir
    [Rails.configuration.uploaded_files_dir, self.owner.id].join("/")
  end

  def commit_file
    if @dirty
      file_dir = get_file_dir
      FileUtils.mkdir_p(file_dir) unless File.directory?(file_dir)
      FileUtils.mv("#{get_temp_dir}/#{file_name}", get_file_path)
      @dirty = false
    end
    true
  end

  def delete_file
    FileUtils.rm(get_file_path) if File.exists?(get_file_path)
    true
  end

  def delete_cookbook_files
    cookbook_name = Rails.configuration.chef_cookbook_name
    cookbook = Cookbook.create(cookbook_name)
    self.topologies.each do |t|
      cookbook.delete_cookbook_file(self, t.owner.id)
    end
    true
  end

  def write_to_disk(file_io)
    temp_dir = get_temp_dir
    FileUtils.mkdir_p(temp_dir) unless File.directory?(temp_dir)
    File.open("#{temp_dir}/#{file_name}", "wb") do |out|
      out.write(file_io.read)
    end
  end

  def get_temp_dir
    ["/tmp", self.owner.id].join("/")
  end

  def file_name_unique
    UploadedFile.all.each do |file|
      if file.id != self.id && file.file_name == self.file_name && file.owner.id == self.owner.id
        errors.add(:file_name, "'#{self.file_name}' have already been taken")
      end
    end
  end

  def file_mutable
    if self.topologies.any?{ |t| t.state != State::UNDEPLOY }
      msg = "Uploaded file #{file_name} cannot be modified. Please make sure it is not being used by any topology"
      raise ParametersValidationError.new(:message => msg)
    end
  end

end