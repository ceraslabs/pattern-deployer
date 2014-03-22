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
require 'chef'

module PatternDeployer
  module Chef
    class Databag
      attr_reader :name, :data

      def initialize(name)
        @name = name
        @data = Hash.new
        @data["id"] = name
        self.extend(Chef::Context)
      end

      def self.create(name)
        databag = new(name)
        databag.create_in_server
        databag
      end

      def self.get(name)
        databag = new(name)
        databag.load_data_from_server
        databag
      end

      def set_data(data)
        @data = data
        @data["id"] = @name
      end

      def delete
        databag = ::Chef::DataBag.new
        databag.name(@name)
        databag.destroy
        @data = nil
      end

      def create_in_server
        databag = ::Chef::DataBag.new
        databag.name(@name)
        databag.create
      end

      def save
        write_data_to_server
      end

      def reload
        load_data_from_server
      end

      def load_data_from_server
        @data = data_bag_item(@name, @name).raw_data
      end

      protected

      def write_data_to_server
        databag_item = ::Chef::DataBagItem.new
        databag_item.data_bag(@name)
        databag_item.raw_data = @data
        databag_item.save
      end

    end
  end
end