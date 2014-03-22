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
require 'pattern_deployer/utils'

module PatternDeployer
  module Chef
    class ChefNodeWrapper
      include PatternDeployer::Utils

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

      def clear_prev_deployment
        %w{ is_success is_failed exception formatted_exception backtrace }.each do |key|
          self.delete_key(key) if self.has_key?(key)
        end
        self.save
      end

      def deployment_published?
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

      def get_db_admin_pwd(db_system)
        case db_system
        when "mysql"
          if self["mysql"]
            return self["mysql"]["server_root_password"]
          end
        when "postgresql"
          if self["postgresql"] && self["postgresql"]["password"]
            return self["postgresql"]["password"]["postgres"]
          end
        else
          raise "Unexpected DBMS #{db_system}. Only 'mysql' or 'postgresql' is allowed"
        end

        nil
      end

      def get_instance_id(cloud)
        case cloud
        when Rails.application.config.ec2
          return self["ec2"]["instance_id"] if self["ec2"]
        when Rails.application.config.openstack
          return self["openstack"]["instance_id"] if self["openstack"]
        when Rails.application.config.notcloud
          # nothing
        else
          raise "unexpected cloud #{cloud}"
        end

        nil
      end

      def get_err_msg
        if self["formatted_exception"]
          msg = self["formatted_exception"]
          trace = backtrack_to_s(self["backtrace"])
          "#{msg}\n#{trace}"
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