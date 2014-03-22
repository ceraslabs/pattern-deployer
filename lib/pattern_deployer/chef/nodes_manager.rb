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
require 'pattern_deployer/chef/node'
require 'pattern_deployer/utils'
require 'singleton'

module PatternDeployer
  module Chef
    class ChefNodesManager
      include PatternDeployer::Utils
      include Singleton

      def initialize
        self.extend(Chef::Context)
        @list_of_nodes = pull_list_of_nodes_from_server
      end

      def get_node(node_name)
        chef_node = nodes.search("name:#{node_name}").first
        if chef_node
          ChefNodeWrapper.new(node_name, chef_node)
        else
          nil
        end
      end

      def delete(node_name)
        return if not @list_of_nodes.include?(node_name)

        node = ::Chef::Node.new
        node.name(node_name)
        node.destroy
      rescue Net::HTTPServerException => e
        self.reload
        #debug
        msg = "Failed to delete chef node #{node_name}: #{e.message}"
        log(msg, e.backtrace)
      ensure
        @list_of_nodes.delete(node_name)
      end

      def reload
        @list_of_nodes = pull_list_of_nodes_from_server
      end

      protected

      def pull_list_of_nodes_from_server
        ::Chef::Node.list.keys
      end

      private_class_method :new

    end
  end
end