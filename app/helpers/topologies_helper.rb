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
require 'pattern_deployer'

module TopologiesHelper

  include PatternDeployer::Deployer::State
  include PatternDeployer::Errors

  def create_topology_scaffold(element, owner)
    validate_topology_element(element)
    Topology.create!(:topology_id => element["id"], :owner => owner, :state => UNDEPLOY)
  end

  def validate_topology_element(element)
    unless element.name == "topology"
      err_msg = "The root element is not of name 'topology'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end

    unless element["id"]
      err_msg = "The topology element doesnot have attribute 'id'. The invalid XML documnet is: #{element}."
      fail PatternValidationError, err_msg
    end
  end

  def get_topology_pattern(xml, topology)
    parse_xml("<root>" + xml + "</root>").find_first("//topology[@id='#{topology.topology_id}']").to_s
  end

end