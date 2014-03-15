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
require 'weakref'

module PatternDeployer
  module Chef
    class ChefNodeWrapper
      def initialize(node_name, node)
        @node_name = node_name
        @node = node
      end

      def get_name
        return @node_name
      end

      def [](key)
        return @node[key]
      end

      #def []=(key, value)
      #  @node[key] = value
      #end

      def has_key?(key)
        @node.has_key?(key)
      end

      def delete_key(key)
        @node.delete(key)
      end

      def save
        @node.save
      end

      def start_deployment
        %w{ is_success is_failed exception formatted_exception backtrace }.each do |key|
          self.delete_key(key) if self.has_key?(key)
        end
        self.save
      end

      def deployment_show_up?
        self.has_key?("is_success")
      end

      def deployment_failed?
        self.has_key?("is_failed") && self["is_failed"]
      end

      def get_server_ip
        if self.has_key?("cloud")
          return self["cloud"]["public_ipv4"]
        elsif self.has_key?("ipaddress")
          return self["ipaddress"]
        else
          #nothing
        end
      end

      def get_private_ip
        if self.has_key?("cloud")
          return self["cloud"]["private_ipv4"]
        elsif self.has_key?("ipaddress")
          return self["ipaddress"]
        else
          #nothing
        end
      end

      def get_err_msg
        if self["formatted_exception"]
          msg = self["formatted_exception"]
          if self["backtrace"]
            msg += "\nTrace: "
            msg += self["backtrace"][0..10].join("\n")
            msg += "\n............"
          end
        end

        msg
      end

      def reload
        ::Chef::Config.from_file(Rails.configuration.chef_config_file)
        Shef::Extensions.extend_context_object(self)
        @node = nodes.search("name:#{@node_name}").first
        raise "Cannot reload node #{@node_name}, since the node doesn't exist" if @node.nil?
      end

      def delete
        #chef_node = nodes.search("name:#{@node_name}").first
        #chef_node.destroy if chef_node
        @node.destroy
        @node = nil
      end

    end
  end
end