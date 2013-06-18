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

  def get_node_pattern(xml, node)
    doc = parse_xml("<root>" + xml + "</root>")
    element = doc.find_first("//topology[@id='#{node.topology.topology_id}']//node[@id='#{node.node_id}']")
    element = doc.find_first("//node[@id='#{node.node_id}']") if element.nil?
    element.to_s
  end

  def node_referenced?(element, node_name)
    !!element.find_first("//*[@node='#{node_name}']")
  end

  def node_declared?(element, node_name)
    !!element.find_first("//node[@id='#{node_name}']")
  end

end