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
require 'pattern_deployer/cloud'
require 'pattern_deployer/errors'
require 'pattern_deployer/utils'

module PatternDeployer
  module Chef
    class ChefNodeWrapper
      include PatternDeployer::Cloud
      include PatternDeployer::Errors
      include PatternDeployer::Utils

      def initialize(node_name, node)
        @node_name = node_name
        @node = node
      end

      def get_name
        @node_name
      end

      def [](key)
        @node[key]
      end

      def key?(key)
        @node.key?(key)
      end

      def save
        @node.save
      end

      def clear_prev_deployment
        %w{ is_success is_failed exception formatted_exception backtrace }.each do |key|
          @node.delete(key)
        end
        save
      end

      def deployment_published?
        @node.key?("is_success")
      end

      def deployment_failed?
        @node.key?("is_failed") && @node["is_failed"]
      end

      def get_server_ip
        if @node.key?("cloud")
          @node["cloud"]["public_ipv4"]
        elsif @node.key?("ipaddress")
          @node["ipaddress"]
        else
          #nothing
        end
      end

      def get_private_ip
        if @node.key?("cloud")
          @node["cloud"]["private_ipv4"]
        elsif @node.key?("ipaddress")
          @node["ipaddress"]
        else
          #nothing
        end
      end

      def get_db_admin_pwd(db_system)
        case db_system
        when "mysql"
          @node["mysql"] && @node["mysql"]["server_root_password"]
        when "postgresql"
          @node["postgresql"] && @node["postgresql"]["password"] && @node["postgresql"]["password"]["postgres"]
        else
          nil
        end
      end

      def get_instance_id(cloud)
        if self.class.ec2?(cloud)
          @node["ec2"] && @node["ec2"]["instance_id"]
        elsif self.class.openstack?(cloud)
          @node["openstack"] && @node["openstack"]["instance_id"]
        else
          nil
        end
      end

      def get_remote_exception
        msg = @node["formatted_exception"]
        backtrace = @node["backtrace"]
        if msg
          exception = RemoteError.new(msg)
          exception.set_backtrace(backtrace) if backtrace
          exception
        else
          nil
        end
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