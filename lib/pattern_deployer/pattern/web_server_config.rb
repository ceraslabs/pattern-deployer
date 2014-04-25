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
require 'pattern_deployer/pattern/config'

module PatternDeployer
  module Pattern
    class WebServerConfig < PatternDeployer::Pattern::Config
      CONFIG_SPECS = [
        {
          element_name:   "service",
          name:           "web_server",
          child_elements: ["war_file"]
        },
        {
          element_name:   "war_file",
          name:           "war_file",
          child_elements: ["file_name", "datasource", "context_params"]
        },
        {
          element_name:   "file_name",
          name:           "name"
        },
        {
          element_name:   "datasource",
          name:           "datasource"
        },
        {
          element_name:   "context_params",
          name:           "context_params"
        }
      ]

      def self.get(element)
        spec = ConfigSpec.new(CONFIG_SPECS, element.name)
        configs = parse_configs(element, spec)
        new(configs)
      end

      def war_file
        @configs["web_server"]["war_file"]
      end

    end
  end
end