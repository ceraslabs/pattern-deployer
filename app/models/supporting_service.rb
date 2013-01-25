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
require "base_deployer"
require "main_deployer"
require "resources_manager"

class SupportingService < ActiveRecord::Base

  @@services_list = ["openvpn", "dns", "host_protection"]
  @@initialized = false

  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :supporting_services

  attr_accessible :state, :name, :owner

  validates :name, :uniqueness => true, :inclusion => { :in => @@services_list, 
                   :message => "%{name} is not a valid supporting service name. Only #{@@services_list.join(',')} are allowed" }
  validates_presence_of :owner

  def self.initialize_db(current_user)
    return if @@initialized

    # populate a list of supporting service into db if needed
    services = SupportingService.all
    @@services_list.each do |service_name|
      my_service = nil
      services.each do |service|
        my_service = service if service.name == service_name
      end

      if my_service.nil?
        my_service = SupportingService.create(:name => service_name, :state => State::UNDEPLOY, :owner => current_user)
      end

      # if there is unexpected termination on previous deployment, reset the state to undeploy
      if my_service.state == State::DEPLOYING
        my_service.state = State::UNDEPLOY
        my_service.save
      end
    end

    @@initialized = true
  end

  def list_of_services
    @@services_list
  end

  def get_state
    if self.state == State::DEPLOYING
      new_state = get_deployer.get_state
      if self.state != new_state
        self.state = new_state
        self.save
      end
    end
    self.state
  end

  def enable(resources)
    my_state = get_state
    if my_state == State::DEPLOY_SUCCESS
      err_msg = "The supporting service '#{self.name}' have already been enabled"
      raise DeploymentError.new(:message => err_msg)
    elsif my_state == State::DEPLOYING
      err_msg = "The supporting service '#{self.name}' is being enabled by another process"
      raise DeploymentError.new(:message => err_msg)
    end

    deployer = get_deployer
    deployer.prepare_deploy(resources)
    deployer.deploy

    self.state = State::DEPLOYING
    save
  end

  def disable(resources)
    my_state = get_state
    if my_state == State::UNDEPLOY || my_state == State::DEPLOYING
      err_msg = "The supporting service '#{self.name}' is not enabled before"
      raise DeploymentError.new(:message => err_msg)
    end

    success, @msg = get_deployer.undeploy(resources)

    DeployersManager.delete_deployer(get_deployer_id)
    self.state = State::UNDEPLOY
    save
  end

  def available?
    get_state == State::DEPLOY_SUCCESS
  end

  def get_status
    case get_state
    when State::UNDEPLOY
      return "disabled"
    when State::DEPLOYING
      return "enabling"
    when State::DEPLOY_SUCCESS
      return "enabled"
    when State::DEPLOY_FAIL
      return "failed"
    else
      raise InternalServerError.new(:message => "Unexpected state #{get_state}") #TODO
    end
  end

  def get_error
    if get_state == State::DEPLOY_FAIL
      return get_deployer.get_err_msg
    else
      return nil
    end
  end

  def get_msg
    @msg
  end


  protected

  def get_deployer
    deployer = DeployersManager.get_deployer(get_deployer_id)
    if deployer.nil?
      #my_resources = ResourcesManager.new
      #my_resources.register_resources(Resource::CREDENTIAL, Credential.get_my_credentials)
      #my_resources.register_resources(Resource::KEY_PAIR, IdentityFile.get_my_files)

      if self.name == "openvpn"
        deployer = CertAuthDeployer.new
      elsif self.name == "dns"
        deployer = DnsDeployer.new
      elsif self.name == "host_protection"
        deployer = OssecServerDeployer.new
      else
        raise "unexpected supporting service #{self.name}"
      end

      DeployersManager.add_deployer(deployer.get_id, deployer)
    end

    deployer
  end

  def get_deployer_id
    SupportingServiceDeployer.get_id(self.name)
  end

  def self.get_all_services
    deployers = Hash.new
    @@services_list.each do |service_name|
      if service_name == "openvpn"
        deployer = CertAuthDeployer.new
      elsif service_name == "dns"
        deployer = DnsDeployer.new
      elsif service_name == "host_protection"
        deployer = OssecServerDeployer.new
      else
        raise "unexpected supporting service #{service_name}"
      end

      deployers[service_name] = deployer
    end

    deployers
  end
end