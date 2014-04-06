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
require 'pattern_deployer'

class Container < ActiveRecord::Base

  include NodesHelper
  include PatternDeployer::Errors

  belongs_to :topology, :autosave => true, :inverse_of => :containers
  belongs_to :owner, :class_name => "User", :foreign_key => "user_id", :inverse_of => :containers
  has_many :nodes, :dependent => :destroy, :as => :parent

  attr_accessible :container_id, :num_of_copies, :owner, :id, :topology

  validates :container_id, :presence => true
  validates :num_of_copies, :numericality => { :only_integer => true, :greater_than => 0 }
  validates_presence_of :topology, :owner
  validate :container_id_unique_within_topology
  validate :container_mutable

  after_initialize :set_default_values
  before_destroy :container_destroyable


  def update_container_attributes(container_element)
    self.container_id = container_element["id"]
    self.num_of_copies = container_element["num_of_copies"] || 1
    container_element.each_element do |element|
      if element.name == "node"
        node = create_node_scaffold(element, self, self.owner)
        node.update_node_attributes(element)
      else
        msg = "Only element of name 'node' can be child element of container. Invalid element: #{element}."
        fail PatternValidationError, msg
      end
    end

    self.save!
  end

  def update_container_connections(container_element)
    container_element.each_element do |element|
      if element.name == "node"
        node = self.nodes.find_by_node_id!(element["id"])
        node.update_node_connections(element)
      end
    end
  end

  def rename(name)
    self.container_id = name
    self.save!
  end

  def get_topology
    self.topology || Topology.find(topology_id)
  end


  protected

  def set_default_values
    self.num_of_copies ||= 1
  end

  def container_id_unique_within_topology
    if Container.where("topology_id = ? AND container_id = ? AND id <> ?", self.topology_id, self.container_id, self.id).first
      errors.add(:container_id, "have already been taken")
    end
  end

  def container_mutable
    if get_topology.locked?
      errors.add(:container_id, "cannot be modified. Please make sure its topology is not deployed or deploying")
    end
  end

  def container_destroyable
    if get_topology.locked?
      msg = "Container #{container_id} cannot be destroyed. Please make sure its topology is not deployed or deploying."
      fail InvalidOperationError, msg
    end
  end

end