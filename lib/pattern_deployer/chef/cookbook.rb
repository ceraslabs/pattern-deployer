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
require 'chef/cookbook_uploader'
require 'chef/knife'
require 'chef/knife/cookbook_upload'
require 'chef/shef/ext'
require 'fileutils'

module PatternDeployer
  module Chef
    class ChefCookbookWrapper
      def initialize(name)
        @name = name
      end

      def self.create(name)
        cookbook_path = [Rails.configuration.chef_repo_dir, "cookbooks", name].join("/")
        if File.directory?(cookbook_path)
          cookbook = new(name)
          ::Chef::Config.from_file(Rails.configuration.chef_config_file)
          Shef::Extensions.extend_context_object(cookbook)

          return cookbook
        else
          return nil
        end
      end

      def add_cookbook_file(file, user_id)
        self.lock do
          existing_file = get_cookbook_file(file, user_id)
          new_file = file.get_file_path
          if existing_file.nil? || !FileUtils.compare_file(new_file, existing_file)
            destination = get_cookbook_file_folder(user_id)
            FileUtils.mkdir_p(destination)
            FileUtils.cp(file.get_file_path, destination)
          end
        end
      end

      def delete_cookbook_file(file, user_id)
        self.lock do
          file_path = get_cookbook_file(file, user_id)
          File.delete(file_path) if file_path
        end
      end

      def get_cookbook_file(file, user_id)
        file_path = [get_cookbook_file_folder(user_id), file.file_name].join("/")
        if File.exists?(file_path)
          return file_path
        else
          return nil
        end
      end

      def get_cookbook_file_folder(user_id = nil)
        path = [Rails.application.config.chef_repo_dir, "cookbooks", @name, "files", "default"]
        path << "user#{user_id}" if user_id
        path.join("/")
      end

      def save
        self.lock do
          uploader = ::Chef::Knife::CookbookUpload.new
          uploader.name_args = [@name]
          uploader.config[:cookbook_path] = "#{Rails.application.config.chef_repo_dir}/cookbooks"
          uploader.run
        end
      end

      def lock
        raise "Unexpected missing of block" unless block_given?

        FileUtils.mkdir_p(File.dirname(lock_file))
        File.open(lock_file, "w") do |file|
          file.flock(File::LOCK_EX)
          yield
        end
      end

      def lock_file
        Rails.root.join("tmp", "cookbooks", "#{@name}.lock")
      end

      private_class_method :new

    end
  end
end