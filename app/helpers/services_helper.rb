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
module ServicesHelper

  def create_service_scaffold(element, parent, owner)
    validate_service_element!(element)
    parent.services.create!(:service_id => element["name"], :owner => owner)
  end

  def validate_service_element!(element)
    unless element.name == "service"
      err_msg = "The root element is not of name 'service'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end

    unless element["name"]
      err_msg = "The service element doesnot have attribute 'name'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end
  end

  def get_service_pattern(xml, service)
    doc = parse_xml("<root>" + xml + "</root>")
    element = doc.find_first("//topology[@id='#{service.topology.topology_id}']//service[@name='#{service.service_id}']")
    element = doc.find_first("//service[@name='#{service.service_id}']") if element.nil?
    element.to_s
  end

end