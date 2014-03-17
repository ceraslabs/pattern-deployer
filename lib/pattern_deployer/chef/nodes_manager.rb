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
require 'chef/knife'
require 'chef/knife/node_delete'
require 'chef/shef/ext'
require 'pattern_deployer/chef/node'
require 'weakref'

module PatternDeployer
  module Chef
    class ChefNodesManager
      def load_nodes_list
        @list_of_nodes = ::Chef::Node.list.keys
        @cache.each_key do |name|
          @cache.delete(name) unless @list_of_nodes.include?(name)
        end
      end

      def initialize
        ::Chef::Config.from_file(Rails.configuration.chef_config_file)
        Shef::Extensions.extend_context_object(self)

        @cache = Hash.new
        load_nodes_list
      end


      @@instance = new

      def self.instance
        return @@instance
      end

      #def create_node(node_name)
      #  return nil if get_node(node_name)

      #  chef_node_wrapper = ChefNodeWrapper.new(node_name)
      #  Shef::Extensions.extend_context_object(chef_node_wrapper)
      #  chef_node_wrapper
      #end

      def get_node(node_name)
        if !@cache.has_key?(node_name) || !@cache[node_name].weakref_alive?
          chef_node = nodes.search("name:#{node_name}").first
          return nil unless chef_node

          chef_node_wrapper = ChefNodeWrapper.new(node_name, chef_node)
          chef_node_wrapper = WeakRef.new(chef_node_wrapper)
          @cache[node_name] = chef_node_wrapper
        end

        return @cache[node_name]
      end

      def delete(node_name)
        return if not @list_of_nodes.include?(node_name)

        if @cache.has_key?(node_name)
          # This delete chef node and cleanup the cache, but it may talk to chef server twice
          chef_node = get_node(node_name)
          raise "Node '#{node_name}' doesnot exist, so it cannot be deleted" if chef_node.nil?
          chef_node.delete
          @cache.delete(node_name)
        else
          # This delete the node without cleaning the cache, and it talk to chef server just once
          node_delete = ::Chef::Knife::NodeDelete.new
          node_delete.name_args = [node_name]
          node_delete.config[:yes] = true
          node_delete.run
        end
      rescue Exception => e
        self.reload
        #debug
        puts "[#{Time.now}]INFO: Failed to delete chef node #{node_name}: #{e.message}"
        puts e.backtrace[0..20].join("\n")
      ensure
        @list_of_nodes.delete(node_name)
      end

      #def deregister(node_name)
      #  @list_of_nodes.delete(node_name)
      #end

      def reload
        load_nodes_list
      end

      private_class_method :new

    end
  end
end