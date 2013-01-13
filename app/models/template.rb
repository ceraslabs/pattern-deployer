require "my_errors"

class Template < ActiveRecord::Base

  include ServicesHelper

  belongs_to :topology, :autosave => true, :inverse_of => :templates
  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :templates
  has_many :services, :dependent => :destroy, :as => :service_container
  has_many :base_template_inheritances, :foreign_key => "template_id", :class_name => "TemplateInheritance", :dependent => :destroy
  has_many :base_templates, :through => :base_template_inheritances
  has_many :derived_template_inheritances, :foreign_key => "base_template_id", :class_name => "TemplateInheritance"
  has_many :derived_templates, :through => :derived_template_inheritances, :source => :template

  attr_accessible :attrs, :template_id, :id, :owner, :topology, :base_templates

  validates :template_id, :presence => true
  validates_presence_of :topology, :owner
  validate :template_id_unique_within_topology

  serialize :attrs, Hash

  before_destroy :delete_templates_inherit_from_this


  def rename(name)
    self.template_id = name
  end

  def extend(template_id)
    can_extend = self.base_templates.find_all_by_template_id(template_id).empty?
    unless can_extend
      raise ParametersValidationError.new(:message => "The base template have already been extended by current template")
    end

    base_template = topology.templates.find_by_template_id!(template_id)
    self.base_templates << base_template
  end

  def unextend(template_id)
    can_unextend = !!self.base_templates.find_by_template_id(template_id)
    unless can_unextend
      raise ParametersValidationError.new(:message => "The base template is not extended by current template before")
    end

    self.base_templates.delete topology.templates.find_by_template_id!(template_id)
  end

  def set_attr(key, value)
    self.attrs[key] = value
  end

  def remove_attr(key)
    raise ParametersValidationError.new(:message => "The attribute key doesnot exist") unless self.attrs.has_key?(key)
    self.attrs.delete key
  end

  def update_template_attributes(template_element)
    self.template_id = template_element["id"]
    template_element.each_element do |element|
      if element.name == "service"
        service = create_service_scaffold(element, self, self.owner)
        service.update_service_attributes(element)
      elsif element.name == "extend"
        next
      elsif !element.attributes? && element.children.size == 1 && element.first.text?
        self.attrs[element.name] = element.content
      else
        err_msg = "Invalid template element: #{element.to_s}"
        raise XmlValidationError.new(:message => err_msg)
      end
    end

    self.save!
  end

  def update_template_connections(template_element)
    template_element.each_element do |element|
      if element.name == "extend"
        base_template_name = element["template"]
        unless base_template_name
          err_msg = "The element #{element.to_s} does not contain attribute 'template'"
          raise XmlValidationError.new(:message => err_msg)
        end

        if base_template_name == self.template_id
          err_msg = "The template #{base_template_name} extend itself"
          raise XmlValidationError.new(:message => err_msg)
        end

        self.base_templates.each do |my_base_template|
          if my_base_template.template_id == base_template_name
            err_msg = "The template #{base_template_name} have already been extended"
            raise XmlValidationError.new(:message => err_msg)
          end
        end

        base_template = Template.where(:topology_id => topology.id, :template_id => base_template_name).first
        unless base_template
          err_msg = "Cannot find template #{base_template_name} within topology #{topology.topology_id}"
          raise XmlValidationError.new(:message => err_msg)
        end

        self.base_templates << base_template
      end
    end

    self.save!
  end


  protected

  def template_id_unique_within_topology
    if Template.where("topology_id = ? AND template_id = ? AND id <> ?", self.topology_id, self.template_id, self.id).first
      errors.add(:template_id, "have already been taken")
    end
  end

  def delete_templates_inherit_from_this
    self.derived_template_inheritances.each do |inheritance|
      inheritance.template.destroy
    end
  end
end