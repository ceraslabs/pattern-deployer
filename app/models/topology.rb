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
require "rexml/document"
require "my_errors"
require "base_deployer"

class Topology < ActiveRecord::Base

  include RestfulHelper
  include ContainersHelper
  include NodesHelper
  include TemplatesHelper

  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :topologies
  has_many   :containers, :dependent => :destroy, :inverse_of => :topology
  has_many   :nodes, :dependent => :destroy, :as => :parent
  has_many   :templates, :dependent => :destroy, :inverse_of => :topology
  has_and_belongs_to_many :uploaded_files
  has_and_belongs_to_many :credentials

  attr_accessible :description, :topology_id, :state, :owner, :containers, :nodes, :templates, :id
  validates :state, :presence => true, :inclusion => { :in => [State::UNDEPLOY, State::DEPLOYING, State::DEPLOY_SUCCESS, State::DEPLOY_FAIL], 
                                                       :message => "%{value} is not a valid state" }
  #TODO underscore in topology name is deprecated
  validates :topology_id, :format => { :with => /\A[[:alnum:]_]+\z/,
                                       :message => "%{value} doesnot match regex /^[[:alnum:]_]+$/" }
  validates_presence_of :owner
  validate :topology_id_unique
  validate :topology_mutable

  after_initialize :set_default_values
  before_destroy :topology_destroyable!


  def update_topology_attributes(topology_element)
    self.topology_id = topology_element["id"]
    topology_element.each_element do |element|
      if element.name == "container"
        container = create_container_scaffold(element, self, self.owner)
        container.update_container_attributes(element)
      elsif element.name == "node"
        node = create_node_scaffold(element, self, self.owner)
        node.update_node_attributes(element)
      elsif element.name == "instance_templates"
        element.each_element do |template_element|
          template = create_template_scaffold(template_element, self, self.owner)
          template.update_template_attributes(template_element)
        end
      elsif element.name == "description"
        self.description = element.content
      else
        raise XmlValidationError.new(:message => "unexpect element '#{element.to_s}', element must be container, node, or instance_templates")
      end
    end

    generate_nodes_if_needed(topology_element)

    self.save!
  end

  def update_topology_connections(topology_element)
    topology_element.each_element do |element|
      if element.name == "node"
        node = self.nodes.find_by_node_id!(element["id"])
        node.update_node_connections(element)
      elsif element.name == "container"
        container = self.containers.find_by_container_id!(element["id"])
        container.update_container_connections(element)
      elsif element.name == "instance_templates"
        element.each_element do |template_element|
          template = self.templates.find_by_template_id!(template_element["id"])
          template.update_template_connections(template_element)
        end
      end
    end
  end

  def deploy(topology_xml, services, resources)
    my_state = get_state
    if my_state == State::DEPLOY_SUCCESS
      err_msg = "The topology '#{self.topology_id}' have already been deployed"
      raise DeploymentError.new(:message => err_msg)
    elsif my_state == State::DEPLOYING
      err_msg = "The topology '#{self.topology_id}' is being deployed by another process"
      raise DeploymentError.new(:message => err_msg)
    end

    deployer = get_deployer
    deployer.prepare_deploy(topology_xml, services, resources)
    deployer.deploy

    self.set_state(State::DEPLOYING)
    self.register_selected_resources(resources)
  end

  def scale(topology_xml, services, resources, nodes, diff)
    my_state = get_state
    if my_state != State::DEPLOY_SUCCESS
      err_msg = "The status of topology '#{self.topology_id}' is not '#{State::DEPLOY_SUCCESS}'"
      raise DeploymentError.new(:message => err_msg)
    end

    deployer = get_deployer
    deployer.prepare_scale(topology_xml, services, resources, nodes, diff)
    deployer.scale

    self.set_state(State::DEPLOYING)
    self.register_selected_resources(resources)
  end

  def repair(topology_xml, services, resources)
    my_state = get_state
    if my_state != State::DEPLOY_FAIL
      err_msg = "The status of topology '#{self.topology_id}' is not '#{State::DEPLOY_FAIL}', nothing to repair"
      raise DeploymentError.new(:message => err_msg)
    end

    deployer = get_deployer
    deployer.prepare_repair(topology_xml, services, resources)
    deployer.repair

    self.set_state(State::DEPLOYING)
    self.register_selected_resources(resources)
  end

  def undeploy(topology_xml, services, resources)
    my_state = get_state
    if my_state == State::UNDEPLOY
      err_msg = "The topology '#{self.topology_id}' is not deployed before"
      raise DeploymentError.new(:message => err_msg)
    end

    deployer = get_deployer
    begin
      success, @msg = deployer.undeploy(topology_xml, services, resources)
    rescue Exception => ex
      @msg ||= ""
      @msg += "[#{Time.now}] #{ex.class.name}: #{ex.message}"
      @msg += "Trace:\n"
      @msg += ex.backtrace.join("\n")

      #debug
      puts @msg
    ensure
      DeployersManager.instance.delete_deployer(self.id)
      self.set_state(State::UNDEPLOY)
    end
  end

  def get_state
    if self.state == State::DEPLOYING
      self.set_state(get_deployer.get_state)
    end

    self.state
  end

  alias :get_deployment_status :get_state

  def get_deployed_nodes(topology_xml)
    if get_state != State::UNDEPLOY
      return get_deployer.list_nodes(topology_xml)
    else
      return Array.new
    end
  end

  def get_error
    deployer = get_deployer
    if deployer && get_state == State::DEPLOY_FAIL
      return deployer.get_update_state == State::DEPLOY_FAIL ? deployer.get_update_error : deployer.get_deploy_error
    else
      return nil
    end
  end

  def get_msg
    @msg
  end

  def unlock(&block)
    begin
      @unlocked = true
      yield
    ensure
      @unlocked = false
    end
  end

  def locked?
    (self.state == State::DEPLOYING || self.state == State::DEPLOY_SUCCESS) && !@unlocked
  end


  protected

  def get_deployer
    deployer = DeployersManager.instance.get_deployer(self.id)
    if deployer.nil?
      deployer = MainDeployer.new(self)
      DeployersManager.instance.add_deployer(self.id, deployer)
    end

    deployer
  end

  def set_default_values
    self.state ||= State::UNDEPLOY
  end

  def topology_mutable
    if self.locked?
      errors.add(:topology_id, "cannot be modified. Please make sure it is not deployed or deploying")
    end
  end

  def topology_destroyable!
    if self.locked?
      msg = "Topology #{topology_id} cannot be destroyed. Please make sure it is not deployed or deploying"
      raise ParametersValidationError.new(:message => msg)
    end
  end

  def set_state(state)
    return if self.state == state
    raise "Cannot set state, the record is dirty: #{self.changes}" if self.changes.size > 0
    self.state = state
    self.unlock{self.save!}
  end

  def generate_nodes_if_needed(topology_element)
    Rails.application.config.nodes.each do |node_xml|
      node_element = parse_xml(node_xml)
      node_name = node_element["id"]
      if node_referenced?(topology_element, node_name) && !node_declared?(topology_element, node_name)
        node = create_node_scaffold(node_element, self, self.owner)
        node.update_node_attributes(node_element)
      end
    end
  end

  def topology_id_unique
    Topology.all.each do |topology|
      if topology.id != self.id && topology.topology_id == self.topology_id && topology.owner.id == self.owner.id
        errors.add(:topology_id, "'#{self.topology_id}' have already been taken")
      end
    end
  end

  def register_selected_resources(resources)
    resources.each do |resource|
      next if !resource.selected? || resource.topologies.exists?(self)
      resource.topologies << self
      resource.unlock{ resource.save }
    end
  end

end
