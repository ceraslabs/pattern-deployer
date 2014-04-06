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
module TemplatesHelper

  def create_template_scaffold(element, parent, owner)
    validate_template_element(element)
    parent.templates.create!(:template_id => element["id"], :owner => owner)
  end

  def validate_template_element(element)
    unless element.name == "template"
      err_msg = "The root element is not of name 'template'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end

    unless element["id"]
      err_msg = "The template element doesnot have attribute 'id'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end
  end

  def get_template_pattern(xml, template)
    doc = parse_xml("<root>" + xml + "</root>")
    element = doc.find_first("//topology[@id='#{template.topology.topology_id}']/template[@id='#{template.template_id}']")
    element = doc.find_first("//template[@id='#{template.template_id}']") if element.nil?
    element.to_s
  end

end