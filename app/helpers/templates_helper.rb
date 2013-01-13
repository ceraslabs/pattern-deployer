module TemplatesHelper

  def create_template_scaffold(element, parent, owner)
    validate_template_element!(element)
    parent.templates.create!(:template_id => element["id"], :owner => owner)
  end

  def validate_template_element!(element)
    unless element.name == "template"
      err_msg = "The root element is not of name 'template'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    unless element["id"]
      err_msg = "The template element doesnot have attribute 'id'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    if element.find_first("service/*[@node]")
      err_msg = "Service inside template should not have any connection to node. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end
  end
end
