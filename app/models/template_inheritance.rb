class TemplateInheritance < ActiveRecord::Base
  belongs_to :template, :foreign_key => "template_id", :class_name => "Template", :autosave => true
  belongs_to :base_template, :foreign_key => "base_template_id", :class_name => "Template", :autosave => true

  attr_accessible :template, :base_template
end