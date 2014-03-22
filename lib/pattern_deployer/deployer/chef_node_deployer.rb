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
require 'pattern_deployer/artifact'
require 'pattern_deployer/chef'
require 'pattern_deployer/deployer/deployer_state'
require 'pattern_deployer/pattern'

module PatternDeployer
  module Deployer
    class ChefNodeDeployer < PatternDeployer::Deployer::BaseDeployer
      include PatternDeployer::Artifact
      include PatternDeployer::Chef
      include PatternDeployer::Errors

      attr_accessor :short_name, :node_id, :services, :artifacts
      deployer_attr_accessor :node_info, :database, :instance_id, :credential_id, :identity_file_id

      def initialize(name, parent_deployer)
        my_id = self.class.join(parent_deployer.deployer_id, "node", name)
        super(my_id, parent_deployer)

        self.short_name = name
        self.node_id = deployer_id
      end

      def reload(node_info, services, artifacts)
        super()
        set_fields(node_info, services, artifacts)
      end

      def reset(node_info = nil, services = nil, artifacts = nil)
        ChefNodesManager.instance.delete(node_id)
        ChefClientsManager.instance.delete(node_id)

        return if node_info.nil? && services.nil? && artifacts.nil?

        super()
        set_fields(node_info, services, artifacts)
      end

      def set_fields(node_info, services, artifacts)
        self.services = services
        self.artifacts = artifacts if artifacts
        self.node_info = node_info
        self.node_info["node_name"] = deployer_id
      end

      def get_id
        deployer_id
      end

      def get_name
        short_name
      end

      def get_pretty_name
        return short_name
      end

      def prepare_deploy
        super()

        generic_prepare

        attributes["timeout_waiting_ip"] = Rails.configuration.chef_wait_ip_timeout
        attributes["timeout_waiting_vpnip"] = Rails.configuration.chef_wait_vpnip_timeout
        attributes["timeout_waiting_members"] = Rails.configuration.chef_wait_balancer_members_timeout
        if @parent.class == TopologyDeployer
          attributes["topology_id"] = @parent.get_topology_id
        end
        attributes["public_ip"] ||= node_info["server_ip"] if node_info["server_ip"]
      end

      def deploy
        super()
        @worker_thread = Thread.new do
          begin
            deploy_helper
            on_deploy_success
          rescue Exception => ex
            on_deploy_failed(self.class.build_err_msg(ex, self))
            #debug
            puts ex.message
            puts ex.backtrace
          end
        end
      end

      def deploy_helper
        #debug
        #puts "[#{Time.now}] Start deploy_node #{@node_name}"

        return if self.external?

        if get_server_ip
          node_info["server_ip"] ||= get_server_ip
          save
        end

        @chef_command = ChefCommand.new(CommandType::DEPLOY, node_info, :services => services)
        @chef_command.add_observer(self)
        @chef_command.execute

        assert_success!(@chef_command)

        #debug
        #puts "[#{Time.now}] deploy_node finished #{@node_name}"
      end

      def prepare_update_deployment
        super()
        generic_prepare
        chef_node = get_chef_node
        chef_node.clear_prev_deployment if chef_node
      end

      def update_deployment
        super()
        @worker_thread = Thread.new do
          begin
            update_deployment_helper
            on_update_success
          rescue Exception => ex
            msg = self.class.build_err_msg(ex, self)
            on_update_failed(msg)
          end
        end
      end

      def update_deployment_helper
        return if self.external?

        if get_server_ip.nil?
          raise "Cannot update node #{node_id}, since its ip is not available"
        end

        unless node_info.has_key?("server_ip")
          node_info["server_ip"] ||= get_server_ip
          save
        end

        #debug
        #puts "[#{Time.now}] Start update_node #{@node_name}"

        @chef_command = ChefCommand.new(CommandType::UPDATE, node_info, :services => services)
        @chef_command.add_observer(self)
        @chef_command.execute

        assert_success!(@chef_command)

        #debug
        #puts "[#{Time.now}] update_node finished #{@node_name}"
      end

      def undeploy
        generic_prepare

        @chef_command.stop if @chef_command
        success, msg = delete_instance

        ChefNodesManager.instance.delete(node_id)
        ChefClientsManager.instance.delete(node_id)

        super

        self.short_name = nil
        self.services = nil
        self.artifacts = nil

        return success, msg
      end

      def kill(options={})
        @chef_command.stop if @chef_command
        super()
      end

      def assert_success!(chef_command, timeout = 60)
        unless chef_command.finished?
          raise "Chef command haven't been executed or it is not finished"
        end

        chef_node = nil
        for i in 1..timeout
          chef_node = get_chef_node
          if chef_node && chef_node.deployment_published?
            break
          end

          sleep 1
        end

        if (chef_command.failed? || chef_node.nil? ||
            !chef_node.deployment_published? ||
            chef_node.deployment_failed?)
          #debug
          log "Chef command failed? #{chef_command.failed?}"
          log "Chef node was nil? #{chef_node.nil?}"
          log "Chef node didn't publish deployment? #{chef_node.deployment_published?}" if chef_node
          log "Chef node indicated deployment failure? #{chef_node.deployment_failed?}" if chef_node

          msg = chef_command.get_err_msg
          inner_msg = chef_node.get_err_msg if chef_node
          raise DeploymentError.new(:message => msg, :inner_message => inner_msg)
        end
      end

      def is_update?
        get_deploy_state == State::DEPLOY_SUCCESS
      end

      def get_server_ip
        private_network? ? attributes["private_ip"] : attributes["public_ip"]
      end

      def external?
        to_bool(self.node_info["is_external"])
      end

      def private_network?
        to_bool(self.node_info["private_network"])
      end

      def application_server?
        services.include?("web_server") && attributes.has_key?("war_file")
      end

      def database_server?
        services.include?("database_server") && self.database
      end

      def get_app_name
        if attributes.has_key?("war_file") && attributes["war_file"].has_key?("name")
          return attributes["war_file"]["name"].sub(/\.war/, "")
        else
          return nil
        end
      end

      def get_app_url
        "http://#{get_server_ip}/#{get_app_name}/" if get_server_ip && get_app_name
      end

      def get_db_system
        database ? database["system"] : nil
      end

      def get_db_user
        database ? database["user"] : nil
      end

      def get_db_pwd
        database ? database["password"] : nil
      end

      def get_db_admin_user
        return nil if database.nil?

        case get_db_system
        when "mysql"
          return "root"
        when "postgresql"
          return "postgres"
        else
          raise "Unexpected DBMS #{get_db_system}. Only 'mysql' or 'postgresql' is allowed"
        end
      end

      def get_db_admin_pwd
        return nil if database.nil?
        return database["admin_password"]
      end

      def monitoring_server?
        services.include?("xcamp_monitoring_server")
      end

      def monitoring_server_url
        "http://" + get_server_ip + "/ganglia/" if get_server_ip
      end

      def server_created?
        attributes.has_key?("public_ip")
      end

      # This method is called to update the databag whenever interesting data print is print to console
      def on_data(key, value)
        return if self.has_key?(key)

        if get_cloud == Rails.application.config.openstack && key == :floating_ip
          key = :public_ip
        end

        self[key] = value
        self.save

        begin
          @parent.on_data(key, value, get_name) if @parent.class == TopologyDeployer
        rescue Exception => ex
          #debug
          puts ex.message
          puts ex.backtrace
        end
      end

      protected

      def generic_prepare
        load_credential
        load_key_pair
        load_cookbook_files
      end

      def get_chef_node
        ChefNodesManager.instance.get_node(node_id)
      end

      def get_instance_id
        return self.instance_id if self.instance_id

        chef_node = get_chef_node
        if chef_node
          chef_node.get_instance_id(get_cloud)
        else
          nil
        end
      end

      def delete_instance
        if get_instance_id.nil?
          return true
        end

        command = ChefCommand.new(CommandType::UNDEPLOY, node_info, :instance_id => get_instance_id)
        success = command.execute
        err_msg = "Command '#{command.get_command}' failed\n" if !success

        return success, err_msg
      end

      def load_key_pair
        raise "Unexpected missing of artifacts" unless artifacts
        if self.identity_file_id
          identity_file = artifacts.find_file_by_id(self.identity_file_id)
          raise "Cannot find identity file with id #{self.identity_file_id}" if identity_file.nil?
          node_info["key_pair_id"] ||= identity_file.key_pair_id
        else
          if get_cloud == Rails.application.config.ec2 || get_cloud == Rails.application.config.openstack
            node_info["key_pair_id"] ||= artifacts.find_keypair_id(get_cloud)
          elsif get_cloud == Rails.application.config.notcloud
            return unless node_info.has_key?("key_pair_id") # if user doesn't specify a private key, he possibly want to use password to login
          else
            raise "unexpected cloud #{get_cloud}"
          end

          keypair_id = node_info["key_pair_id"]
          raise "Cannot find any keypair for cloud #{get_cloud}" if keypair_id.nil?
          identity_file = artifacts.find_identity_file(keypair_id) if keypair_id
          raise "Cannot find identity file with keypair id #{keypair_id}" if identity_file.nil?
        end

        identity_file.select
        node_info["identity_file"] = identity_file.get_file_path
        self.identity_file_id ||= identity_file.get_id
      end

      def load_credential
        raise "Unexpected missing of artifacts" unless artifacts
        credential_name = node_info["use_credential"]

        if self.credential_id
          credential = artifacts.find_credential_by_id(self.credential_id)
        elsif credential_name
          credential = artifacts.find_credential_by_name(credential_name, get_cloud)
        else
          if get_cloud == Rails.application.config.ec2
            credential = artifacts.find_ec2_credential
          elsif get_cloud == Rails.application.config.openstack
            credential = artifacts.find_openstack_credential
          elsif get_cloud == Rails.application.config.notcloud
            return # no action is needed
          else
            raise "unexpected cloud #{get_cloud}"
          end
        end

        if credential.nil?
          err_msg = "Can not find any credential to authenticate to #{get_cloud}, please upload your credential first"
          raise DeploymentError.new(:message => err_msg)
        end

        credential.select
        node_info["aws_access_key_id"]     = credential.access_key_id if credential.respond_to?(:access_key_id)
        node_info["aws_secret_access_key"] = credential.secret_access_key if credential.respond_to?(:secret_access_key)
        node_info["openstack_username"]    = credential.username if credential.respond_to?(:username)
        node_info["openstack_password"]    = credential.password if credential.respond_to?(:password)
        node_info["openstack_tenant"]      = credential.tenant if credential.respond_to?(:tenant)
        node_info["openstack_endpoint"]    = credential.endpoint if credential.respond_to?(:endpoint)
        self.credential_id ||= credential.get_id
      end

      def load_cookbook_files
        cookbook_name = Rails.configuration.chef_cookbook_name
        cookbook = ChefCookbookWrapper.create(cookbook_name)
        [FileType::WAR_FILE, FileType::SQL_SCRIPT_FILE].each do |file_type|
          next if not attributes.has_key?(file_type)

          file_id = attributes["#{file_type}_id"]
          file_name = attributes[file_type]["name"]
          if file_id
            file = artifacts.find_file_by_id(file_id)
          elsif file_name
            file = artifacts.find_file_by_name(file_name)
          else
            raise "Unexpected missing file ID and name"
          end

          if file.nil?
            err_msg = "The file #{file_name} cannot be found. Please ensure that file has been uploaded before deploy"
            raise DeploymentError.new(:message => err_msg)
          elsif not File.exists?(file.get_file_path)
            err_msg = "The file #{file_name} cannot be found in path #{file.get_file_path}"
            raise InternalServerError.new(:message => err_msg)
          end
          file.select
          cookbook.add_or_update_file(file, get_owner_id)
          attributes["#{file_type}_id"] ||= file.get_id
        end
      end

      #def validate_cloud_provider!
      #  cloud = get_cloud
      #  if cloud && !Rails.application.config.supported_clouds.include?(cloud)
      #    err_msg = "The cloud #{cloud} is not supported. Only #{Rails.application.config.supported_clouds.join(';')} are supported"
      #    raise DeploymentError.new(:message => err_msg)
      #  end
      #end

      def on_deploy_success
        super()
        on_deploy_finish
        save
      end

      def on_update_success
        super()
        on_update_finish
        save
      end

      def on_deploy_failed(err_msg)
        super(err_msg)
        on_deploy_finish
        save
      end

      def on_update_failed(err_msg)
        super(err_msg)
        on_update_finish
        save
      end

      def on_deploy_finish
        load_chef_node_data
      end

      def on_update_finish
        load_chef_node_data
      end

      def load_chef_node_data
        chef_node = get_chef_node
        return if chef_node.nil?

        # The attribute 'output' is optionally set by individual node to pass message back to PDS.
        # The data stored in this attribute should be of the Hash format.
        if chef_node.has_key?("output")
          chef_node["output"].each do |key, value|
            attributes[key] = value
          end
        end

        attributes["public_ip"] ||= chef_node.get_server_ip if chef_node.get_server_ip
        attributes["private_ip"] ||= chef_node.get_private_ip if chef_node.get_private_ip
        database["admin_password"] ||= chef_node.get_db_admin_pwd(get_db_system)
        instance_id ||= chef_node.get_instance_id(get_cloud)
      end

      def get_cloud
        cloud = node_info["cloud"]
        if cloud.class == String
          return cloud.downcase
        elsif cloud.class == NilClass
          return Rails.application.config.notcloud
        else
          return cloud
        end
      end

    end
  end
end