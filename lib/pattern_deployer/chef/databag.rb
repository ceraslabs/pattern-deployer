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
require 'chef/shef/ext'

module PatternDeployer
  module Chef
    class DatabagWrapper
      def initialize(name, manager, data = Hash.new)
        @name = name
        @manager = manager
        @data = data
        @data["id"] = name
      end

      def get_name
        return @name
      end

      def get_data
        @data
      end

      def set_data(data)
        @data = data
        @data["id"] = @name
      end

      def delete
        databag = ::Chef::DataBag.new
        databag.name(@name)
        databag.destroy
      rescue Net::HTTPServerException => e
        @manager.reload
        #debug
        puts "[#{Time.now}]INFO: Failed to delete chef client #{@name}: #{e.message}"
        puts e.backtrace[0..20].join("\n")
      ensure
        @data = nil
        @manager.deregister_databag(@name)
      end

      def save
        @manager.reload_and_retry_if_failed do
          databag_item = get_databag_item
          databag_item.raw_data = @data
          databag_item.save
        end
        @manager.register_databag(@name)
      end

      def reload
        @data = data_bag_item(@name, @name).raw_data
      end

      protected

      def get_databag_item
        if @manager.databag_exist?(@name) && @manager.databag_item_exist?(@name)
          return data_bag_item(@name, @name)
        end

        if @manager.databag_exist?(@name)
          databag = ::Chef::DataBag.new
          databag.name(@name)
          databag.destroy
        end
        databag = ::Chef::DataBag.new
        databag.name(@name)
        databag.save
        databag_item = ::Chef::DataBagItem.new
        databag_item.data_bag(@name)
        databag_item
      end

    end
  end
end