require "my_errors"

class Service < ActiveRecord::Base

  include ServicesHelper

  has_many :service_to_node_refs, :dependent => :destroy
  has_many :nodes, :through => :service_to_node_refs
  belongs_to :service_container, :autosave => true, :polymorphic => true
  belongs_to :owner, :class_name => "User", :foreign_key => "user_id", :inverse_of => :services
  belongs_to :topology

  attr_accessible :properties, :service_id, :nodes, :service_container, :owner, :id, :service_to_node_refs, :topology

  validates :service_id, :presence => true
  validates_presence_of :service_container, :owner
  #validate :service_is_supported

  serialize :properties, Array

  after_initialize :set_default_values
  after_create :set_topology
  after_save :set_topology


  def rename(name)
    self.service_id = name
    self.save!
  end

  def redefine(service_element)
    ActiveRecord::Base.transaction do
      validate_service_element!(service_element)
      clear_service_attributes
      update_service_attributes(service_element)
      clear_service_connections
      update_service_connections(service_element)
    end
  rescue ActiveRecord::RecordInvalid => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end

  def update_service_attributes(service_element)
    self.service_id = service_element["name"]
    service_element.each_element do |element|
      unless element["node"]
        self.properties << element.to_s
      end
    end

    self.save!
  end

  def update_service_connections(service_element)
    service_element.each_element do |element|
      next unless element["node"]

      ref_node_id = element["node"]
      ref_node = Node.where(:topology_id => get_topology.id, :node_id => ref_node_id).first
      unless ref_node
        err_msg = "The node '#{ref_node_id}' dose not exist. The invalid element is: #{service_element.to_s}"
        raise XmlValidationError.new(:message => err_msg)
      end
      ref = ServiceToNodeRef.new(:ref_name => element.name.to_s, :service => self, :node => ref_node)
      self.service_to_node_refs << ref

      self.save!
    end
  end

  def get_topology
    if service_container_type == "Template"
      template = Template.find(service_container_id)
      return template.topology
    elsif service_container_type == "Node"
      node = Node.find(service_container_id)
      return node.get_topology
    else
      raise "Unexpected service container type #{service_container_type}"
    end
  end


  protected

  def clear_service_connections
    self.service_to_node_refs.destroy
    self.service_to_node_refs.clear
  end

  def clear_service_attributes
    self.properties.clear
  end

  def set_default_values
    self.properties ||= Array.new
  end

  def set_topology
    if self.topology.nil? && !@performed
      @performed = true
      self.topology = get_topology
      self.save!
    end
  end

  #def service_is_supported
  #  if self.service_id && !Rails.application.config.supported_node_services.include?(self.service_id)
  #    errors.add(:service_id, "#{self.service_id} is not supported")
  #  end
  #end
end