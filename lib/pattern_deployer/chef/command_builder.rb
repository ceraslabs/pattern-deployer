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
require 'pattern_deployer/utils'

module PatternDeployer
  module Chef
    class BaseCommandBuilder
      include PatternDeployer::Utils

      def initialize(node_name, node_info, services = Array.new)
        @node_name = node_name
        @node_info = node_info
        @services = services
      end

      def build_create_command
        identity_file = @node_info["identity_file"]
        ssh_user = @node_info["ssh_user"]
        ssh_password = @node_info["ssh_password"]
        port = @node_info["port"]
        timeout = Float(@node_info["timeout"] || "0")
        cloud = @node_info["cloud"]
        verbose = to_bool(@node_info["verbose"])

        command = ""
        command += "-x #{ssh_user} "
        command += "-N #{@node_name} "
        command += "-i #{identity_file} " if identity_file
        command += "-P #{ssh_password} " if ssh_password
        command += "-p #{port} " if port
        command += "--no-host-key-verify "
        command += "--template-file #{Rails.root.join("chef-repo", ".chef", "bootstrap", "chef-full.erb")} "
        if verbose
          command += "-VV "
        else
          command += "-V "
        end

        command += "-r '"
        if @services.size > 0
          command += @services.map{|s| "recipe[NestedQEMU::#{s}]"}.join(",")
        else
          command += "recipe[NestedQEMU::common]"
        end
        command += "' "

        command
      end

    end

    class EC2CommandBuilder < BaseCommandBuilder
      def build_create_command
        security_groups =  @node_info["security_groups"]
        image =  @node_info["image_id"]
        instance_type =  @node_info["instance_type"]
        key_pair_id =  @node_info["key_pair_id"]
        zone =  @node_info["availability_zone"]
        region = @node_info["region"]

        command = "knife ec2 server create "
        command += "-I #{image} "
        command += "-f #{instance_type} " if instance_type
        command += "-S #{key_pair_id} " if key_pair_id
        command += "-G #{security_groups} " if security_groups
        command += "-Z #{zone} " if zone
        command += "--region #{region} " if region
        command += build_auth_info

        command += super()
        command
      end

      def build_delete_command(instance_id)
        command = "knife ec2 server delete #{instance_id} -y "
        command += "-N #{@node_name} "
        command += "--region #{@node_info["region"]} " if @node_info["region"]
        command += build_auth_info
      end

      protected

      def build_auth_info
        access_key_id = @node_info["aws_access_key_id"]
        secret_access_key = @node_info["aws_secret_access_key"]
        if access_key_id.nil? || secret_access_key.nil?
          raise ParametersValidationError.new(:message => "EC2 auth info missing")
        end

        command = "-A #{access_key_id} "
        command += "-K #{secret_access_key} "
        command
      end

    end

    class OpenStackCommandBuilder < BaseCommandBuilder
      def build_create_command
        image_id =  @node_info["image_id"]
        instance_type =  @node_info["instance_type"]
        key_pair_id =  @node_info["key_pair_id"]
        is_private_network = to_bool(@node_info["private_network"])
        region = @node_info["region"]
        system_file = @node_info["system_file"] #TODO support multiple system files
        openstack_hints = @node_info["openstack_hints"]

        command = "knife openstack server create "
        command += "-I #{image_id} "
        command += "-f #{instance_type} " if instance_type
        command += "-S #{key_pair_id} "
        command += "--region #{region} " if region
        command += build_auth_info
        if is_private_network
          command += "--private-network "
        else
          command += "-a "
          command += "--auto-alloc-floating-ip " if Rails.configuration.openstack_auto_allocate_ip
        end
        if system_file
          command += "--system-file-path #{system_file["path"]} "
          command += "--system-file-content '#{system_file["content"]}' " if system_file["content"]
        end
        if openstack_hints
          str_hints = openstack_hints.map{ |key, value| "#{key}=#{value}" }.join(",")
          command += "--openstack-hints '#{str_hints}' "
        end

        command += super()
        command
      end

      def build_delete_command(instance_id)
        command = "knife openstack server delete #{instance_id} -y "
        command += "-N #{@node_name} "
        command += "--region #{@node_info["region"]} " if @node_info["region"]
        command += "--dealloc-floating-ip " if Rails.configuration.openstack_auto_deallocate_ip
        command += build_auth_info
      end

      protected

      def build_auth_info
        username = @node_info["openstack_username"]
        password = @node_info["openstack_password"]
        tenant   = @node_info["openstack_tenant"]
        endpoint = @node_info["openstack_endpoint"]
        if [username, password, tenant, endpoint].any?{|v| v.nil?}
          raise ParametersValidationError.new(:message => "openstack auth info missing")
        end

        command = "-A #{username} "
        command += "-K #{password} "
        command += "-T #{tenant} "
        command += "--openstack-api-endpoint #{endpoint} "
        command
      end

    end

    class BootstrapCommandBuilder < BaseCommandBuilder
      def initialize(node_name, node_info, services, server_ip)
        super(node_name, node_info, services)
        @server_ip = server_ip
      end

      def build_create_command
        if @server_ip.nil?
          msg = "Cannot update node #{@node_name}, since its ip is not available"
          raise ParametersValidationError.new(:message => msg)
        end

        command = "knife bootstrap "
        command += "#{@server_ip} "
        command += "--sudo "
        command += super()
        command
      end

    end
  end
end