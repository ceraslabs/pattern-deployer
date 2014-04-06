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
module ContainersHelper

  def create_container_scaffold(element, topology, owner)
    validate_container_element!(element)
    topology.containers.create!(:container_id => element["id"], :num_of_copies => element["num_of_copies"] || 1, :owner => owner)
  end

  def validate_container_element!(element)
    unless element.name == "container"
      err_msg = "The root element is not of name 'container'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end

    unless element["id"]
      err_msg = "The container element doesnot have attribute 'id'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end
  end

  def get_container_pattern(xml, container)
    doc = parse_xml("<root>" + xml + "</root>")
    element = doc.find_first("//topology[@id='#{container.topology.topology_id}']/container[@id='#{container.container_id}']")
    element = doc.find_first("//container[@id='#{container.container_id}']") if element.nil?
    element.to_s
  end

end