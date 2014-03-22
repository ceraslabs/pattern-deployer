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
require 'pattern_deployer/chef/context'
require 'pattern_deployer/chef/databag'
require 'pattern_deployer/utils'
require 'singleton'

module PatternDeployer
  module Chef
    class DatabagsManager
      include PatternDeployer::Utils
      include Singleton

      def initialize
        self.extend(Chef::Context)
        @list_of_databags = pull_list_of_databags_from_server
      end

      def read(name)
        if databag_exist?(name)
          databag = Databag.get(name)
          databag.data
        else
          nil
        end
      rescue Net::HTTPServerException => e
        # log exception
        msg = "Failed to update databag #{name}: #{e.message}"
        log(msg, e.backtrace)
        # try to fix inconsistency
        self.reload
        nil
      end

      def write(name, data)
        retried ||= false

        if databag_exist?(name)
          databag = Databag.new(name)
        else
          databag = Databag.create(name)
          register(databag)
        end
        databag.set_data(data)
        databag.save
      rescue Net::HTTPServerException => e
        if retried
          raise
        else
          retried = true
        end
        # log exception
        msg = "Failed to update databag #{name}: #{e.message}"
        log(msg, e.backtrace)

        # try to recover
        self.reload
        retry
      end

      def delete(name)
        databag = Databag.new(name)
        databag.delete
      rescue Net::HTTPServerException => e
        msg = "Failed to delete databag #{name}: #{e.message}"
        log(msg, e.backtrace)
      ensure
        deregister(databag)
      end

      def reload
        @list_of_databags = pull_list_of_databags_from_server
      end

      protected

      def databag_exist?(name)
        databags = @list_of_databags
        databags.include?(name)
      end

      def databag_item_exist?(name)
        !!search(name.to_sym, "id:#{name}").first
      end

      def pull_list_of_databags_from_server
        ::Chef::DataBag.list.keys
      end

      def register(databag)
        unless @list_of_databags.include?(databag.name)
          @list_of_databags << databag.name
        end
      end

      def deregister(databag)
        @list_of_databags.delete(databag.name)
      end

    end
  end
end