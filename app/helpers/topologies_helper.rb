module TopologiesHelper

  def create_topology_scaffold(element, owner)
    validate_topology_element!(element)
    Topology.create!(:topology_id => element["id"], :owner => owner, :state => State::UNDEPLOY)
  end

  def validate_topology_element!(element)
    unless element.name == "topology"
      err_msg = "The root element is not of name 'topology'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    unless element["id"]
      err_msg = "The topology element doesnot have attribute 'id'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end
  end
end
