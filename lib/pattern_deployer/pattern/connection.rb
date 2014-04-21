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
require 'pattern_deployer/errors'
require 'pattern_deployer/pattern/reference'

module PatternDeployer
  module Pattern
    module Connection
      def self.create(source_node, sink_node, ref_type)
        case ref_type
        when ReferenceType::DB_CONNECTION
          connection = {
            web_server: source_node,
            database: sink_node
          }
        when ReferenceType::LB_MEMBER
          connection = {
            load_balancer: source_node,
            member: sink_node
          }
        when ReferenceType::CHEF_SERVER
          connection = {
            chef_server: source_node,
            chef_client: sink_node
          }
        when ReferenceType::MON_SERVER
          connection = {
            monitoring_client: source_node,
            monitoring_server: sink_node
          }
        else
          fail "The reference type '#{ref_type}' is invalid or undefined."
        end

        OpenStruct.new(connection)
      end

    end
  end
end