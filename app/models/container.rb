require "my_errors"

class Container < ActiveRecord::Base

  include NodesHelper

  belongs_to :topology, :autosave => true, :inverse_of => :containers
  belongs_to :owner, :class_name => "User", :foreign_key => "user_id", :inverse_of => :containers
  has_many :nodes, :dependent => :destroy, :as => :parent

  attr_accessible :container_id, :num_of_copies, :owner, :id, :topology

  validates :container_id, :presence => true
  validates :num_of_copies, :numericality => { :only_integer => true }
  validates_presence_of :topology, :owner
  validate :container_id_unique_within_topology

  after_initialize :set_default_values


  def update_container_attributes(container_element)
    self.container_id = container_element["id"]
    self.num_of_copies = container_element["num_of_copies"] || 1
    container_element.each_element do |element|
      if element.name == "node"
        node = create_node_scaffold(element, self, self.owner)
        node.update_node_attributes(element)
      else
        raise XmlValidationError.new(:message => "unexpect element '#{element.to_s}', only element of name 'node' can be child element of container")
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


  protected

  def set_default_values
    self.num_of_copies ||= 1
  end

  def container_id_unique_within_topology
    if Container.where("topology_id = ? AND container_id = ? AND id <> ?", self.topology_id, self.container_id, self.id).first
      errors.add(:container_id, "have already been taken")
    end
  end
end
