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
require "pattern_deployer"

class Node < ActiveRecord::Base
  include ServicesHelper
  include PatternDeployer::Errors
  include PatternDeployer::Utils::Xml

  has_and_belongs_to_many :templates
  has_many :services, :dependent => :destroy, :as => :service_container
  has_many :service_to_node_refs, :dependent => :destroy
  belongs_to :parent, :autosave => true, :polymorphic => true
  belongs_to :owner, :class_name => "User", :foreign_key => "user_id", :inverse_of => :nodes
  belongs_to :topology

  attr_accessible :attrs, :node_id, :templates, :services, :parent, :owner, :id, :topology

  #TODO underscore in node name is deprecated
  validates :node_id, :format => { :with => /\A[[:alnum:]_]+\z/,
                                   :message => "%{value} doesnot match regex /^[[:alnum:]_]+$/" }
  validates_presence_of :parent, :owner
  validate :node_id_unique_within_topology
  validate :node_mutable

  serialize :attrs, Hash

  after_initialize :set_default_values
  after_create :set_topology
  after_save :set_topology
  before_destroy :node_destroyable


  def rename(name)
    self.node_id = name
    self.save!
  end

  def add_template(template_id)
    template = Template.where(:template_id => template_id).first 
    if template.nil?
      err_msg = "Cannot find a template with name #{template_id}."
      fail ParametersValidationError, err_msg
    end
    templates << template
    self.save!
  end

  def remove_template(template_id)
    template = templates.where(:template_id => template_id).first
    if template.nil?
      err_msg = "The template '#{template_id}' was not added, so cannot remove."
      fail ParametersValidationError, err_msg
    end

    templates.delete(template)
    self.save!
  end

  def set_attr(key, value)
    self.attrs[key] = value
    self.save!
  end

  def remove_attr(key)
    fail ParametersValidationError, "The attribute key doesnot exist." unless self.attrs.has_key?(key)
    self.attrs.delete(key)
    self.save!
  end

  def update_node_attributes(node_element)
    self.node_id = node_element["id"]
    node_element.each_element do |element|
      if element.name == "service"
        service = create_service_scaffold(element, self, self.owner)
        service.update_service_attributes(element)
      elsif element.name == "use_template"
        next
      elsif hash_format?(element)
        node_attr = xml_element_to_hash(element)
        self.attrs.merge!(node_attr)
      else
        fail PatternValidationError, "Invalid node element: #{element}."
      end
    end

    self.save!
  end

  def update_node_connections(node_element)
    node_element.each_element do |element|
      if element.name == "use_template"
        template_name = element["name"]
        unless template_name
          err_msg = "The 'use_template' element does not contain attribute 'name'."
          fail PatternValidationError, err_msg
        end

        self.templates.each do |my_template|
          if my_template.template_id == template_name
            err_msg = "The template #{template_name} have already been used."
            fail PatternValidationError, err_msg
          end
        end

        template = Template.where(:topology_id => get_topology.id, :template_id => template_name).first
        unless template
          err_msg = "Cannot find template '#{template_name}' within topology '#{topology.topology_id}'."
          fail PatternValidationError, err_msg
        end

        self.templates << template
      elsif element.name == "service"
        service = self.services.find_by_service_id!(element["name"])
        service.update_service_connections(element)
      end
    end

    self.save!
  end

  def get_topology
    if self.topology
      return self.topology
    elsif parent_type == "Container"
      container = Container.find(parent_id)
      return container.topology
    elsif parent_type == "Topology"
      return Topology.find(parent_id)
    else
      fail "Unexpected parent type #{parent_type}."
    end
  end


  protected

  def set_default_values
    self.attrs ||= Hash.new
  end

  def set_topology
    if self.topology.nil? && !@performed
      @performed = true
      self.topology = get_topology
      self.topology.unlock{self.save!}
    end
  end

  def node_id_unique_within_topology
    if Node.where("topology_id = ? AND node_id = ? AND id <> ?", self.topology_id, self.node_id, self.id).first
      errors.add(:node_id, "have already been taken")
    end
  end

  def node_mutable
    if get_topology.locked?
      errors.add(:node_id, "cannot be modified. Please make sure its topology is not deployed or deploying")
    end
  end

  def node_destroyable
    if get_topology.locked?
      msg = "Node #{node_id} cannot be destroyed. Please make sure its topology is not deployed or deploying."
      fail InvalidOperationError, msg
    end
  end

end