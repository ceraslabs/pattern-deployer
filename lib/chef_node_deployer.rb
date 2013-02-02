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
    #@chef_node = ChefNodesManager.instance.get_node(@node_name)
    #if @chef_node.nil?
    #  @chef_node = ChefNodesManager.instance.create_node(@node_name)
    #end
  end

  def get_id
    #if @parent.nil?
    #  raise "Undefined parent deployer for node #{@node_name}"
    #end

    prefix = @parent.get_id
    [prefix, "node", @short_name].join("_")
  end

  def get_name
    @short_name
  end

  def get_name_without_suffix
    @short_name.sub(/_\d+$/, "")
  end

  def get_deployment_status
    get_state
  end

  def get_services_info
    infos = Hash.new
    @services.each do |service_name|
      info = Hash.new
      if service_name == "web_server" && self.has_key?("war_file")
        info["url"] = get_app_url if get_app_url
      elsif service_name == "database_server" && self.has_key?("database")
        info["user"] = self["database"]["user"]
        info["password"]  = self["database"]["password"]
        info["url"]  = get_db_url if get_db_url
        info["root_password"] = chef_node["mysql"]["server_root_password"] if chef_node = get_chef_node
      end

      (infos[service_name] ||= Array.new) << info
    end

    infos
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

    #validate_cloud_provider!
    load_credential
    load_key_pair
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
    load_key_pair

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
    success, msg = delete_instance
    #ChefClientsManager.instance.delete(@node_name)
    #ChefNodesManager.instance.delete(@node_name)
    @short_name = nil
    @node_info = nil
    @services = nil
    @resources = nil

    super()

    return success, msg
  end

  def set_services(services)
    @services = services
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
        err_msg += "Please check the output of the command in log file '#{chef_command.get_log_file}'"
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
    self["deploy_state"]
  end

  def get_update_state
    self["update_state"]
  end

  def is_update?
    get_deploy_state == State::DEPLOY_SUCCESS
  end

  def get_server_ip
    self["public_ip"]
  end

  # This method is called to update the databag whenever interesting data print is print to console
  def on_data(key, value)
    return if self.has_key?(key)

    if get_cloud == Rails.application.config.openstack && key == :floating_ip
      self[:public_ip] = value
    elsif get_cloud != Rails.application.config.openstack && key == :public_ip
      self[:public_ip] = value
    else
      self[key] = value
    end
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
    if chef_node.has_key?("ec2") && chef_node["ec2"].has_key?("instance_id")
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
    load_credential
    load_key_pair

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

    key_pair_id = @node_info["key_pair_id"].strip
    identity_file = @resources.find_identity_file(key_pair_id)
    if identity_file
      @node_info["identity_file"] = identity_file.get_file_path
    else
      raise "Cannot find identity file for key pair id #{key_pair_id}"
    end
  end

  def load_credential
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
      self["deploy_state"] = get_deploy_state
    end
  end

  def on_update_finish
    load_output
    self["update_state"] = get_update_state
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

  def get_app_url
    app_name = self["war_file"]["name"].sub(/\.war/, "")
    "http://" + get_server_ip + "/" + app_name if get_server_ip
  end

  def get_db_url
    if get_server_ip
      url = "http://" + get_server_ip + ":"
      if self["database"]["system"] == "mysql"
        url += "3306"
      elsif self["database"]["system"] == "postgresql"
        url += "5432"
      elsif self["database"].has_key?("port")
        url += self["database"]["port"]
      else
        raise "Unexpected case"
      end
    else
      return nil
    end
  end
end