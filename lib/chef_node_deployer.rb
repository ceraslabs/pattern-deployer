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

  attr_accessor :short_name, :node_id, :services, :resources
  deployer_attr_accessor :node_info, :database, :instance_id, :credential_id

  def initialize(name, parent_deployer)
    my_id = [parent_deployer.deployer_id, "node", name].join("_")
    super(my_id, parent_deployer.topology_id, parent_deployer)

    self.short_name = name
    self.node_id = deployer_id
  end

  def reload(node_info, services, resources)
    super()
    chef_node = get_chef_node
    chef_node.reload if chef_node

    set_fields(node_info, services, resources)
  end

  def reset(node_info = nil, services = nil, resources = nil)
    ChefNodesManager.instance.delete(node_id)
    ChefClientsManager.instance.delete(node_id)

    return if node_info.nil? && services.nil? && resources.nil?

    super()
    set_fields(node_info, services, resources)
  end

  def set_fields(node_info, services, resources)
    self.services = services
    self.resources = resources if resources
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
    name_no_suffix = short_name.sub(/_\d+$/, "")
    if @parent.class == TopologyDeployer && @parent.topology.get_num_of_copies(name_no_suffix) > 1
      return short_name
    else
      return name_no_suffix
    end
  end

  def prepare_deploy
    super()

    generic_prepare

    attributes["timeout_waiting_ip"] = Rails.configuration.chef_wait_ip_timeout
    attributes["timeout_waiting_vpnip"] = Rails.configuration.chef_wait_vpnip_timeout
    if @parent.class == TopologyDeployer
      attributes["topology_id"] = @parent.get_topology_id
    end
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

    if get_server_ip
      node_info["server_ip"] = get_server_ip
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
    chef_node.start_deployment if chef_node
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
    if get_server_ip.nil?
      raise "Cannot update node #{node_id}, since its ip is not available"
    end

    unless node_info.has_key?("server_ip")
      node_info["server_ip"] = get_server_ip
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
    super

    self.short_name = nil
    self.services = nil
    self.resources = nil

    return success, msg
  end

  def wait(timeout)
    if @worker_thread
      @worker_thread.join(timeout)
    else
      true
    end
  end

  def kill(options={})
    @chef_command.stop if @chef_command
    timeout = 10
    if @worker_thread && !@worker_thread.join(timeout)
      @worker_thread.kill
    end
    set_deploy_state(State::DEPLOY_FAIL) if self.deploy_state == State::DEPLOYING
    set_update_state(State::DEPLOY_FAIL) if self.update_state == State::DEPLOYING
  end

  def assert_success!(chef_command, timeout = 60)
    unless chef_command.finished?
      raise "Chef command haven't been executed or it is not finished"
    end

    chef_node = nil
    for i in 1..timeout
      chef_node = get_chef_node
      break if chef_node && chef_node.deployment_show_up?

      sleep 1
    end

    if (chef_command.failed? ||
        (chef_node && !chef_node.deployment_show_up?) ||
        (chef_node && chef_node.deployment_failed?))
      msg = chef_command.get_err_msg
      inner_msg = chef_node.get_err_msg if chef_node
      raise DeploymentError.new(:message => msg, :inner_message => inner_msg)
    end
  end

  def is_update?
    get_deploy_state == State::DEPLOY_SUCCESS
  end

  def get_server_ip
    attributes["public_ip"]
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
    "http://" + get_server_ip + "/" + get_app_name if get_server_ip && get_app_name
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

  #TODO handle other DBMS
  def get_db_root_pwd
    return nil if database.nil?

    if database && database.has_key?("root_password")
      return database["root_password"]
    end

    chef_node = get_chef_node
    if chef_node && chef_node.has_key?("mysql") && chef_node["mysql"].has_key?("server_root_password")
      root_pwd = chef_node["mysql"]["server_root_password"]
      if self.primary_deployer?
        database["root_password"] = root_pwd
        save
      end
    end

    root_pwd
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
  end

  def get_chef_node
    ChefNodesManager.instance.get_node(node_id)
  end

  def get_instance_id
    return self.instance_id if self.instance_id

    cloud = get_cloud
    if cloud == Rails.application.config.ec2
      chef_node = get_chef_node
      self.instance_id = chef_node["ec2"]["instance_id"] if chef_node && chef_node.has_key?("ec2") && chef_node["ec2"].has_key?("instance_id")
    elsif cloud == Rails.application.config.openstack
      chef_node = get_chef_node
      self.instance_id = chef_node["openstack"]["instance_id"] if chef_node && chef_node.has_key?("openstack") && chef_node["openstack"].has_key?("instance_id")
    elsif cloud == Rails.application.config.notcloud
      # don't need to do anything
    else
      raise "unexpected cloud #{cloud}"
    end

    self.save if self.instance_id
    self.instance_id
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
    return unless node_info.has_key?("key_pair_id")
    raise "Unexpected missing of resources" unless resources

    key_pair_id = node_info["key_pair_id"].strip
    identity_file = resources.find_identity_file(key_pair_id)
    if identity_file
      node_info["identity_file"] = identity_file.get_file_path
    else
      raise "Cannot find identity file for key pair id #{key_pair_id}"
    end
  end

  def load_credential
    raise "Unexpected missing of resources" unless resources

    if credential_id
      # this node already have a credential assigned, so update the credential content
      credential = resources.find_credential_by_id(credential_id)
      node_info["aws_access_key_id"]     = credential.access_key_id if credential.respond_to?(:access_key_id)
      node_info["aws_secret_access_key"] = credential.secret_access_key if credential.respond_to?(:secret_access_key)
      node_info["openstack_username"]    = credential.username if credential.respond_to?(:username)
      node_info["openstack_password"]    = credential.password if credential.respond_to?(:password)
      node_info["openstack_tenant"]      = credential.tenant if credential.respond_to?(:tenant)
      node_info["openstack_endpoint"]    = credential.endpoint if credential.respond_to?(:endpoint)
      return
    end

    # assign this node a credential
    if get_cloud == Rails.application.config.ec2
      credential = resources.find_my_ec2_credential
      if credential.nil?
        err_msg = "Can not find any credential to authenticate with EC2 cloud, please upload your credential first"
        raise DeploymentError.new(:message => err_msg)
      end
      credential_id = credential.credential_id
      node_info["aws_access_key_id"]     = credential.access_key_id
      node_info["aws_secret_access_key"] = credential.secret_access_key
    elsif get_cloud == Rails.application.config.openstack
      credential = resources.find_my_openstack_credential
      if credential.nil?
        err_msg = "Can not find any credential to authenticate with OpenStack cloud, please upload your credential first"
        raise DeploymentError.new(:message => err_msg)
      end
      credential_id = credential.credential_id
      node_info["openstack_username"] = credential.username
      node_info["openstack_password"] = credential.password
      node_info["openstack_tenant"]   = credential.tenant
      node_info["openstack_endpoint"] = credential.endpoint
    elsif get_cloud == Rails.application.config.notcloud
      # no action is needed
    else
      raise "unexpected cloud #{get_cloud}"
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
      attributes["public_ip"] ||= chef_node.get_server_ip
      attributes["private_ip"] ||= chef_node.get_private_ip
    end
  end

  def on_update_finish
    load_output
  end

  def load_output
    chef_node = get_chef_node
    if chef_node && chef_node.has_key?("output")
      chef_node["output"].each do |key, value|
        attributes[key] = value
      end
    end
  end

  def get_cloud
    cloud = node_info["cloud"]
    if cloud.class == String
      return cloud.downcase
    else
      return cloud
    end
  end

end