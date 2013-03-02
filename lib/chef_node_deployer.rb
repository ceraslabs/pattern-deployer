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
require "chef_client"
require "chef_command"
require "chef_databag"
require "chef_node"
require "topology_wrapper"

class ChefNodeDeployer < BaseDeployer

  def initialize(name, node_info, services, resources, parent_deployer)
    @short_name = name
    @node_info  = node_info
    @services   = services
    @resources  = resources

    super(parent_deployer)

    @node_name = get_id
    @node_info.merge!({"node_name" => @node_name})
  end

  def get_id
    prefix = @parent.get_id
    [prefix, "node", @short_name].join("_")
  end

  def get_name
    @short_name
  end

  def get_pretty_name
    name_no_suffix = @short_name.sub(/_\d+$/, "")
    if @parent.class == TopologyDeployer && @parent.get_topology.get_num_of_copies(name_no_suffix) > 1
      return @short_name
    else
      return name_no_suffix
    end
  end

  def get_deployment_status
    get_state
  end

  def prepare_deploy
    super()

    ChefNodesManager.instance.delete(@node_name)
    ChefClientsManager.instance.delete(@node_name)

    self["timeout_waiting_ip"] = Rails.configuration.chef_wait_ip_timeout
    self["timeout_waiting_vpnip"] = Rails.configuration.chef_wait_vpnip_timeout
    if @parent.class == TopologyDeployer
      self["topology_id"] = @parent.get_topology_id
    end
    self.save

    generic_prepare
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
        #puts ex.message
        #puts ex.backtrace
      end
    end
  end

  def deploy_helper
    #debug
    #puts "[#{Time.now}] Start deploy_node #{@node_name}"

    @node_info["server_ip"] = get_server_ip if get_server_ip
    chef_command = ChefCommand.new(CommandType::DEPLOY, @node_info, :services => @services)
    chef_command.add_observer(self)
    chef_command.execute

    assert_success!(chef_command)

    #debug
    #puts "[#{Time.now}] deploy_node finished #{@node_name}"
  end

  def prepare_update_deployment
    super()
    generic_prepare
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
    unless get_server_ip
      raise "Cannot update node #{@node_name}, since its ip is not available"
    end
    @node_info["server_ip"] = get_server_ip

    #debug
    #puts "[#{Time.now}] Start update_node #{@node_name}"

    chef_command = ChefCommand.new(CommandType::UPDATE, @node_info, :services => @services)
    chef_command.add_observer(self)
    chef_command.execute

    assert_success!(chef_command)

    #debug
    #puts "[#{Time.now}] update_node finished #{@node_name}"
  end

  def undeploy
    generic_prepare

    success, msg = delete_instance

    super()
    @short_name = nil
    @node_info = nil
    @services = nil
    @resources = nil

    return success, msg
  end

  def get_services
    @services
  end

  def set_services(services)
    @services = services
  end

  def set_resources(resources)
    @resources = resources
  end

  def get_node_name
    @node_name
  end

  def wait(timeout = 600)
    if @worker_thread
      @worker_thread.join(timeout)
    else
      true
    end
  end

  def assert_success!(chef_command, timeout = 60)
    is_success = false
    for i in 1..timeout
      chef_node = get_chef_node
      if chef_node && chef_node.has_key?("is_success")
        is_success = chef_node["is_success"]
        break
      end

      if i != timeout
        sleep 1
      else
        err_msg = "Failed to deploy chef node '#{@node_name}' with command: #{chef_command.get_command}\n"
        err_msg += "Output of the command:\n"
        err_msg += `cat #{chef_command.get_log_file}`
        raise err_msg
      end
    end

    unless is_success
      msg = "Failed to execute command: #{chef_command.get_command}, deployment of node '#{get_id}' failed"
      chef_node = get_chef_node
      if chef_node
        inner_msg = chef_node.get_err_msg
      end

      raise DeploymentError.new(:message => msg, :inner_message => inner_msg)
    end
  end

  def get_deploy_state
    self["deploy_state"] || State::UNDEPLOY
  end

  def get_update_state
    self["update_state"] || State::UNDEPLOY
  end

  def is_update?
    get_deploy_state == State::DEPLOY_SUCCESS
  end

  def get_server_ip
    self["public_ip"]
  end

  def application_server?
    @services.include?("web_server") && self.has_key?("war_file")
  end

  def database_server?
    @services.include?("database_server") && self.has_key?("database")
  end

  def get_app_name
    raise "Applicaton information missing" if !self.has_key?("war_file") || !self["war_file"].has_key?("name")
    self["war_file"]["name"].sub(/\.war/, "")
  end

  def get_app_url
    "http://" + get_server_ip + "/" + get_app_name if get_server_ip
  end

  def get_db_system
    self["database"]["system"]
  end

  def get_db_user
    self["database"]["user"]
  end

  def get_db_pwd
    self["database"]["password"]
  end

  def get_db_root_pwd
    #TODO handle other db
    chef_node = get_chef_node
    if  chef_node && chef_node.has_key?("mysql") && chef_node["mysql"].has_key?("server_root_password")
      chef_node["mysql"]["server_root_password"]
    end
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
  end

  def get_chef_node
    ChefNodesManager.instance.get_node(@node_name)
  end

  def get_instance_id
    cloud = get_cloud
    if cloud == Rails.application.config.ec2
      instance_id = get_ec2_instance_id
    elsif cloud == Rails.application.config.openstack
      instance_id = get_openstack_instance_id
    elsif cloud == Rails.application.config.notcloud
      # don't need to do anything
    else
      raise "unexpected cloud #{cloud}"
    end
  end

  def get_ec2_instance_id
    chef_node = get_chef_node
    if chef_node && chef_node.has_key?("ec2") && chef_node["ec2"].has_key?("instance_id")
      return chef_node["ec2"]["instance_id"].strip
    else
      return nil
    end
  end

  def get_openstack_instance_id
    if self.has_key?("instance_id")
      return self["instance_id"].strip
    else
      return nil
    end
  end

  def delete_instance
    instance_id = get_instance_id
    if instance_id.nil?
      return true
    end

    command = ChefCommand.new(CommandType::UNDEPLOY, @node_info, :instance_id => instance_id)
    success = command.execute
    err_msg = "Command '#{command.get_command}' failed\n" if !success

    return success, err_msg
  end

  def load_key_pair
    return unless @node_info.has_key?("key_pair_id")
    raise "Unexpected missing of resources" unless @resources

    key_pair_id = @node_info["key_pair_id"].strip
    identity_file = @resources.find_identity_file(key_pair_id)
    if identity_file
      @node_info["identity_file"] = identity_file.get_file_path
    else
      raise "Cannot find identity file for key pair id #{key_pair_id}"
    end
  end

  def load_credential
    raise "Unexpected missing of resources" unless @resources
    if !self.has_key?("credential_id")
      if get_cloud == Rails.application.config.ec2
        credential = @resources.find_my_ec2_credential
        if credential
          @node_info["aws_access_key_id"]     = credential.access_key_id
          @node_info["aws_secret_access_key"] = credential.secret_access_key
        else
          err_msg = "Can not find any credential to authenticate with EC2 cloud, please upload your credential first"
          raise DeploymentError.new(:message => err_msg)
        end
      elsif get_cloud == Rails.application.config.openstack
        credential = @resources.find_my_openstack_credential
        if credential
          @node_info["openstack_username"] = credential.username
          @node_info["openstack_password"] = credential.password
          @node_info["openstack_tenant"]   = credential.tenant
          @node_info["openstack_endpoint"] = credential.endpoint
        else
          err_msg = "Can not find any credential to authenticate with OpenStack cloud, please upload your credential first"
          raise DeploymentError.new(:message => err_msg)
        end
      elsif get_cloud == Rails.application.config.notcloud
        # no action is needed
      else
        raise "unexpected cloud #{get_cloud}"
      end

      if credential.credential_id
        self["credential_id"] = credential.credential_id
        self.save
      end
    else
      credential = @resources.find_credential_by_id(self["credential_id"])
      @node_info["aws_access_key_id"]     = credential.access_key_id if credential.respond_to?(:access_key_id)
      @node_info["aws_secret_access_key"] = credential.secret_access_key if credential.respond_to?(:secret_access_key)
      @node_info["openstack_username"]    = credential.username if credential.respond_to?(:username)
      @node_info["openstack_password"]    = credential.password if credential.respond_to?(:password)
      @node_info["openstack_tenant"]      = credential.tenant if credential.respond_to?(:tenant)
      @node_info["openstack_endpoint"]    = credential.endpoint if credential.respond_to?(:endpoint)
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
    load_output
    chef_node = get_chef_node
    if chef_node
      self["public_ip"] ||= chef_node.get_server_ip
      self["private_ip"] ||= chef_node.get_private_ip
    end
  end

  def on_update_finish
    load_output
  end

  def load_output
    chef_node = get_chef_node
    if chef_node && chef_node.has_key?("output")
      chef_node["output"].each do |key, value|
        self[key] = value
      end
    end
  end

  def get_cloud
    cloud = @node_info["cloud"]
    if cloud.class == String
      return cloud.downcase
    else
      return cloud
    end
  end

end