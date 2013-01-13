module NodesHelper

  def create_node_scaffold(element, parent, owner)
    validate_node_element!(element)
    parent.nodes.create!(:node_id => element["id"], :owner => owner)
  end

  def validate_node_element!(element)
    unless element.name == "node"
      err_msg = "The root element is not of name 'node'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    unless element["id"]
      err_msg = "The node element doesnot have attribute 'id'. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end

    if element.find("nest_within").size > 1
      err_msg = "A node cannot nest within more than one node. The invalid XML documnet is: #{element.to_s}"
      raise XmlValidationError.new(:message => err_msg)
    end
  end
end
