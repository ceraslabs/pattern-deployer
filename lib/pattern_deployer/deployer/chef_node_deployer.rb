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
require 'pattern_deployer/cloud'
require 'pattern_deployer/chef'
require 'pattern_deployer/deployer/state'
require 'pattern_deployer/pattern'

module PatternDeployer
  module Deployer
    class ChefNodeDeployer < PatternDeployer::Deployer::BaseDeployer
      include PatternDeployer::Artifact
      include PatternDeployer::Cloud
      include PatternDeployer::Chef
      include PatternDeployer::Errors

      attr_accessor :short_name, :services, :artifacts
      # these attributes persist in Chef Databag
      attribute_accessor :node_info, :database, :instance_id, :cloud_credential, :identity_file,
                         :war_file, :sql_script_file, :public_ip, :private_ip, :web_server

      def initialize(name, parent_deployer)
        my_id = create_deployer_id(name, parent_deployer)
        super(my_id, parent_deployer)

        self.short_name = name
      end

      def update
        super
      end

      def reset
        delete_chef_node
        delete_chef_client
        super
      end

      def set_fields(node_info, services, artifacts)
        self.node_info = node_info.deep_dup
        self.services = services
        self.artifacts = artifacts

        self.node_info && self.node_info["node_name"] = deployer_id
      end

      def set_fields_if_not_before(node_info, services, artifacts)
        self.node_info ||= node_info.deep_dup if node_info
        self.services ||= services if services
        self.artifacts ||= artifacts if artifacts

        self.node_info && self.node_info["node_name"] ||= deployer_id
      end

      def get_id
        deployer_id
      end

      def get_name
        short_name
      end

      def get_pretty_name
        short_name
      end

      def prepare_deploy
        super
        load_artifacts
        init_attributes
      end

      def deploy
        @worker_thread = Thread.new do
          run(ChefCommand::DEPLOY)
        end
      end

      def prepare_update_deployment
        super
        load_artifacts
        chef_node = get_chef_node
        chef_node && chef_node.clear_prev_deployment
      end

      def update_deployment
        @worker_thread = Thread.new do
          run(ChefCommand::UPDATE)
        end
      end

      def undeploy
        @chef_command && @chef_command.stop
        load_artifacts

        # terminate the cloud instance if any
        delete_instance

        delete_chef_node
        delete_chef_client
        self.short_name = nil
        self.services = nil
        self.artifacts = nil
        self.node_info = nil
        super
      end

      def kill(options={})
        @chef_command && @chef_command.stop
        super()
      end

      def get_server_ip
        private_network? ? private_ip : public_ip
      end

      def application_server?
        services.include?("web_server")
      end

      def database_server?
        services.include?("database_server")
      end

      def get_app_name
        if web_server && web_server["war_file"] && web_server["war_file"]["name"]
          web_server["war_file"]["name"].sub(/\.war/, "")
        else
          nil
        end
      end

      def get_app_url
        "http://#{get_server_ip}/#{get_app_name}/" if get_server_ip && get_app_name
      end

      def get_db_system
        database && database["system"]
      end

      def get_db_user
        database && database["user"]
      end

      def get_db_pwd
        database && database["password"]
      end

      def get_db_admin_user
        database && database["admin_user"]
      end

      def get_db_admin_pwd
        database && database["admin_password"]
      end

      def monitoring_server?
        services.include?("xcamp_monitoring_server")
      end

      def monitoring_server_url
        server_ip = get_server_ip
        server_ip && "http://#{server_ip}/ganglia/"
      end

      def server_created?
        !public_ip.nil?
      end

      def set_web_server_configs(configs)
        attributes.merge!(configs.to_hash)
        self.war_file = configs.war_file if configs.war_file
      end

      def set_database_configs(configs)
        attributes.merge!(configs.to_hash)
        self.sql_script_file = configs.db_script_file if configs.db_script_file
      end

      # This method is a callback by Chef Command. It is called by ChefCommand instance to set attributes in Databag.
      def on_data(key, value)
        return if attributes.key?(key)

        key = :public_ip if openstack? && key == :floating_ip
        attributes[key.to_s] = value
        save

        begin
          @parent.on_data(key, value, get_name) if @parent.respond_to?(:on_data)
        rescue StandardError => e
          log e.message, e.backtrace # DEBUG
          # Suppress the exception here, since the chef command needs to be running until finish.
        end
      end

      protected

      def run(command)
        return if external_node?

        is_deploy = case command
                    when ChefCommand::DEPLOY then true
                    when ChefCommand::UPDATE then false
                    else
                      msg = "Unexpected chef command #{command}"
                      raise InternalServerError.new(msg)
                    end
        if node_info["server_ip"].nil? && get_server_ip
          node_info["server_ip"] = get_server_ip
          save
        end

        @chef_command = ChefCommand.new(command, node_info, :services => services)
        @chef_command.add_observer(self)
        @chef_command.execute

        assert_execution_success
        is_deploy ? on_deploy_success : on_update_success
      rescue Exception => e
        msg = self.class.build_err_msg(e, self)
        is_deploy ? on_deploy_failed(msg) : on_update_failed(msg)
        log e.message, e.backtrace # DEBUG
        raise e
      end

      def assert_execution_success(timeout = 60)
        unless @chef_command.finished?
          msg = "Chef command haven't been executed or it is not finished"
          raise DeploymentError.new(:message => msg)
        end

        for i in 1..timeout
          chef_node = get_chef_node
          break if chef_node && chef_node.deployment_published?

          sleep 1
        end

        if @chef_command.failed? ||
           chef_node.nil? ||
           !chef_node.deployment_published? ||
           chef_node.deployment_failed?
          # DEBUG
          log "Chef command failed? #{@chef_command.failed?}"
          log "Chef node was nil? #{chef_node.nil?}"
          log "Chef node didn't publish deployment? #{chef_node.deployment_published?}" if chef_node
          log "Chef node indicated deployment failure? #{chef_node.deployment_failed?}" if chef_node

          msg = @chef_command.get_err_msg
          inner_msg = chef_node && chef_node.get_err_msg
          raise DeploymentError.new(:message => msg, :inner_message => inner_msg)
        end
      end

      def load_artifacts
        load_credential
        load_keypair
        load_cookbook_files
      end

      def init_attributes
        attributes["timeout_waiting_ip"] = Rails.configuration.chef_wait_ip_timeout
        attributes["timeout_waiting_members"] = Rails.configuration.chef_wait_balancer_members_timeout
        self.public_ip ||= node_info["server_ip"] if node_info["server_ip"]
      end

      def get_chef_node
        ChefNodesManager.instance.get_node(deployer_id)
      end

      def get_instance_id
        return instance_id if instance_id

        chef_node = get_chef_node
        chef_node && chef_node.get_instance_id(cloud)
      end

      def delete_instance
        instance_id = get_instance_id
        return true if instance_id.nil?

        command = ChefCommand.new(ChefCommand::UNDEPLOY, node_info, :instance_id => instance_id)
        success = command.execute
        unless success
          log "Failed to delete instance #{instance_id}"
          log command.get_err_msg
        end
      end

      def load_keypair
        file = find_identity_file
        if file
          file.mark_selected
          node_info["identity_file"] = file.get_file_path
          node_info["key_pair_id"] ||= file.key_pair_id
          self.identity_file ||= Hash.new
          identity_file["id"] ||= file.get_id
        else
          if ec2? || openstack?
            msg = "No identity file for authenticating '#{deployer_id}' with cloud '#{cloud}'"
            raise DeploymentError.new(:message => msg)
          else
            # no action needed
          end
        end
      end

      def find_identity_file
        file_id = identity_file && identity_file["id"]
        if file_id
          artifacts.find_file_by_id(file_id)
        else
          keypair_id = node_info["key_pair_id"] || artifacts.find_keypair_id(cloud)
          if keypair_id
            artifacts.find_identity_file(keypair_id)
          else
            nil
          end
        end
      end

      def load_credential
        credential = find_credential
        if credential
          credential.mark_selected
          node_info["aws_access_key_id"]     = credential.access_key_id     if credential.respond_to?(:access_key_id)
          node_info["aws_secret_access_key"] = credential.secret_access_key if credential.respond_to?(:secret_access_key)
          node_info["openstack_username"]    = credential.username          if credential.respond_to?(:username)
          node_info["openstack_password"]    = credential.password          if credential.respond_to?(:password)
          node_info["openstack_tenant"]      = credential.tenant            if credential.respond_to?(:tenant)
          node_info["openstack_endpoint"]    = credential.endpoint          if credential.respond_to?(:endpoint)
          self.cloud_credential ||= Hash.new
          cloud_credential["id"] ||= credential.get_id
        else
          if ec2? || openstack?
            err_msg = "Cannot find any credential to authenticate to #{cloud}, please upload your credential first."
            raise DeploymentError.new(:message => msg)
          else
            # no action needed
          end
        end
      end

      def find_credential
        credential_id = cloud_credential && cloud_credential["id"]
        credential_name = node_info["use_credential"]
        if credential_id
          artifacts.find_credential_by_id(credential_id)
        elsif credential_name
          artifacts.find_credential_by_name(credential_name, cloud)
        else
          if ec2?
            artifacts.find_ec2_credential
          elsif openstack?
            artifacts.find_openstack_credential
          else
            nil
          end
        end
      end

      def load_cookbook_files
        cookbook_name = Rails.configuration.chef_cookbook_name
        cookbook = ChefCookbookWrapper.create(cookbook_name)
        [FileType::WAR_FILE, FileType::SQL_SCRIPT_FILE].each do |file_type|
          next unless attributes.key?(file_type)

          file = find_file(file_type)
          if file
            file.mark_selected
            cookbook.add_or_update_file(file, topology_owner_id)
            attributes[file_type]["id"] ||= file.get_id
          else
            err_msg = "Cannot file of type #{file_type}. Please upload one before deploy"
            raise DeploymentError.new(:message => err_msg)
          end
        end
      end

      def find_file(file_type)
        file_id = attributes[file_type]["id"]
        file_name = attributes[file_type]["name"]
        if file_id
          artifacts.find_file_by_id(file_id)
        elsif file_name
          artifacts.find_file_by_name(file_name)
        else
          nil
        end
      end

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
        attributes.merge!(chef_node["output"]) if chef_node.key?("output")
        self.public_ip ||= chef_node.get_server_ip if chef_node.get_server_ip
        self.private_ip ||= chef_node.get_private_ip if chef_node.get_private_ip
        self.instance_id ||= chef_node.get_instance_id(cloud)
        database["admin_password"] ||= chef_node.get_db_admin_pwd(get_db_system) if database
      end

      def cloud
        node_info["cloud"]
      end

      def ec2?
        self.class.ec2?(node_info["cloud"])
      end

      def openstack?
        self.class.openstack?(node_info["cloud"])
      end

      def create_deployer_id(name, parent_deployer)
        self.class.join(parent_deployer.deployer_id, "node", name)
      end

      def delete_chef_node
        ChefNodesManager.instance.delete(deployer_id)
      end

      def delete_chef_client
        ChefClientsManager.instance.delete(deployer_id)
      end

      def external_node?
        to_bool(node_info["is_external"])
      end

      def private_network?
        to_bool(node_info["private_network"])
      end

    end
  end
end