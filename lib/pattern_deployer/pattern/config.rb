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
require 'pattern_deployer/utils'

module PatternDeployer
  module Pattern
    module Config
      include PatternDeployer::Errors
      extend PatternDeployer::Utils::Xml

      def self.parse_configs(element_name, config_specs, element = nil)
        config_spec = find_config_spec(element_name, config_specs)
        fail "No config specification for '#{element_name}'." if config_spec.nil?

        configs = Hash.new
        config_key = config_spec[:key]
        if config_spec[:child_elements]
          sub_configs = Hash.new
          config_spec[:child_elements].each do |child_element_name|
            child_element = find_child_element(element, child_element_name) if element
            sub_configs.merge!(parse_configs(child_element_name, config_specs, child_element))
          end
          configs[config_key]= sub_configs
        else
          config_value = element.content.strip if element
          config_value ||= config_spec[:default_value]
          if config_value
            if config_spec[:allow_values]
              validate_config_value!(config_value, config_spec[:allow_values])
            end
            configs[config_key] = config_value
          end
        end

        configs
      end

      protected

      def self.validate_config_value!(value, allow_values)
        unless allow_values.include?(value)
          msg = "The value '#{value}' is not allowed. Allowed values: #{allow_values.inspect}."
          fail PatternValidationError, msg
        end
      end

      def self.find_config_spec(element_name, config_specs)
        config_specs.find do |spec|
          spec[:element] == element_name
        end
      end

      def self.find_child_element(parent_element, name)
        parent_element.find_first(name)
      end

    end
  end
end