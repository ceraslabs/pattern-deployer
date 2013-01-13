module ContainersHelper

  def create_container_scaffold(element, topology, owner)
    validate_container_element!(element)
    topology.containers.create!(:container_id => element["id"], :num_of_copies => element["num_of_copies"] || 1, :owner => owner)
  end

  def validate_container_element!(element)
    unless element.name == "container"
      err_msg = "The root element is not of name 'container'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    unless element["id"]
      err_msg = "The container element doesnot have attribute 'id'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end
  end
end
