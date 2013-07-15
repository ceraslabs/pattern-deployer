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
require "chef_cookbook"
require "chef_databag"
require "chef_node"
require "topology_wrapper"

class ChefNodeDeployer < BaseDeployer

  attr_accessor :short_name, :node_id, :services, :resources
  deployer_attr_accessor :node_info, :database, :instance_id, :credential_id, :identity_file_id

  def initialize(name, parent_deployer)
    my_id = self.class.join(parent_deployer.deployer_id, "node", name)
    super(my_id, parent_deployer.topology_id, parent_deployer)

    self.short_name = name
    self.node_id = deployer_id
  end

  def reload(node_info, services, resources)
    super()
    get_chef_node.reload if get_chef_node

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
    name_no_suffix = short_name.sub(/-\d+$/, "")
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
    get_chef_node.start_deployment if get_chef_node
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
    self.resources = nil

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

    for i in 1..timeout
      if get_chef_node
        get_chef_node.reload
        break if get_chef_node.deployment_show_up?
      end

      sleep 1
    end

    if (chef_command.failed? || get_chef_node.nil? ||
        !get_chef_node.deployment_show_up? ||
        get_chef_node.deployment_failed?)
      #debug
      puts "Chef command failed? #{chef_command.failed?}"
      puts "Chef node is nil? #{get_chef_node.nil?}"
      puts "Chef node didn't show up? #{get_chef_node.deployment_show_up?}" if get_chef_node
      puts "Chef node indicate failed? #{get_chef_node.deployment_failed?}" if get_chef_node

      msg = chef_command.get_err_msg
      inner_msg = get_chef_node.get_err_msg if get_chef_node
      raise DeploymentError.new(:message => msg, :inner_message => inner_msg)
    end
  end

  def is_update?
    get_deploy_state == State::DEPLOY_SUCCESS
  end

  def get_server_ip
    attributes["public_ip"]
  end

  def external?
    !!self.node_info["is_external"]
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
    return database["admin_password"] if database["admin_password"]

    case get_db_system
    when "mysql"
      if self.primary_deployer? && get_chef_node && get_chef_node["mysql"] &&
                                   get_chef_node["mysql"]["server_root_password"]
        database["admin_password"] = get_chef_node["mysql"]["server_root_password"]
        save
      end
    when "postgresql"
      if self.primary_deployer? && get_chef_node && get_chef_node["postgresql"] &&
                                   get_chef_node["postgresql"]["password"] && get_chef_node["postgresql"]["password"]["postgres"]
        database["admin_password"] = get_chef_node["postgresql"]["password"]["postgres"]
        save
      end
    else
      raise "Unexpected DBMS #{get_db_system}. Only 'mysql' or 'postgresql' is allowed"
    end

    database["admin_password"]
  end

  def monitoring_server?
    services.include?("monitoring_server")
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

    cloud = get_cloud
    if cloud == Rails.application.config.ec2
      self.instance_id = get_chef_node["ec2"]["instance_id"] if get_chef_node && get_chef_node.has_key?("ec2") && get_chef_node["ec2"].has_key?("instance_id")
    elsif cloud == Rails.application.config.openstack
      self.instance_id = get_chef_node["openstack"]["instance_id"] if get_chef_node && get_chef_node.has_key?("openstack") && get_chef_node["openstack"].has_key?("instance_id")
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
    raise "Unexpected missing of resources" unless resources
    keypair_id = node_info["key_pair_id"]
    if keypair_id
      keypair_id.strip!
    else
      keypair_id = find_keypair_id
    end

    if self.identity_file_id
      identity_file = resources.find_file_by_id(self.identity_file_id)
    elsif keypair_id
      identity_file = resources.find_identity_file(keypair_id)
    else
      return # No action is needed
    end

    raise "Cannot find identity file for key pair id #{keypair_id}" if identity_file.nil?

    identity_file.select
    node_info["identity_file"] = identity_file.get_file_path
    self.identity_file_id ||= identity_file.get_id
  end

  def load_credential
    raise "Unexpected missing of resources" unless resources
    credential_name = node_info["use_credential"]

    if self.credential_id
      credential = resources.find_credential_by_id(self.credential_id)
    elsif credential_name
      credential = resources.find_credential_by_name(credential_name, get_cloud)
    else
      if get_cloud == Rails.application.config.ec2
        credential = resources.find_ec2_credential
      elsif get_cloud == Rails.application.config.openstack
        credential = resources.find_openstack_credential
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
        file = resources.find_file_by_id(file_id)
      elsif file_name
        file = resources.find_file_by_name(file_name)
      else
        raise "Unexpected missing file ID and name"
      end

      if file.nil? || !File.exists?(file.get_file_path)
        err_msg = "The file #{file_name} does not exist. Please upload that file before deploy"
        raise DeploymentError.new(:message => err_msg)
      end
      file.select
      cookbook.add_cookbook_file(file, get_owner_id)
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
    load_output
    if get_chef_node
      get_chef_node.reload
      attributes["public_ip"] ||= get_chef_node.get_server_ip if get_chef_node.get_server_ip
      attributes["private_ip"] ||= get_chef_node.get_private_ip if get_chef_node.get_private_ip
    end
  end

  def on_update_finish
    load_output
  end

  def load_output
    if get_chef_node && get_chef_node.has_key?("output")
      get_chef_node["output"].each do |key, value|
        attributes[key] = value
      end
    end
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