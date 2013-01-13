module ServicesHelper

  def create_service_scaffold(element, parent, owner)
    validate_service_element!(element)
    parent.services.create!(:service_id => element["name"], :owner => owner)
  end

  def validate_service_element!(element)
    unless element.name == "service"
      err_msg = "The root element is not of name 'service'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    unless element["name"]
      err_msg = "The service element doesnot have attribute 'name'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end
  end
end
