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

module XcampServiceHelper
  include PatternDeployer::Utils::Xml

  def process_management_logic(service_element)
    return unless management_logic?(service_element)

    managed_topology_element = service_element.find_first("managed_topology")
    context_params_element = context_params(managed_topology_element)
    managed_topology_element.remove!

    war_file_element = service_element.find_first("war_file")
    war_file_element << context_params_element

    service_element["name"] = "web_server"
    service_element
  end

  protected

  def management_logic?(service_element)
    service_element["name"] == "xcamp_management_logic"
  end

  def context_params(element)
    topology_name = element.content.strip
    topology = Topology.find_by_name!(topology_name)
    share_topology(topology)
    hash_to_xml_element("context_params", {
      topology: topology_name,
      pdsBasePath: base_path(topology)
    })
  end

  def share_topology(topology)
    return if owner.has_shared?(topology)
    success, msg = owner.share(topology)
    fail msg unless success
  end

  def base_path(topology)
    path = topology.url_shared_by(owner)
    path.sub(/topologies\/\d+\Z/, "")
  end

end