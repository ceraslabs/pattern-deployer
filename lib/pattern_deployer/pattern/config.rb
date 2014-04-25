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
    class Config
      include PatternDeployer::Errors
      extend PatternDeployer::Utils::Xml

      class ConfigSpec
        def initialize(specs, name)
          @specs = specs
          @spec = find_spec(name)
        end

        def find(name)
          self.class.new(@specs, name)
        end

        def config_name
          @spec[:name]
        end

        def element_name
          @spec[:element_name]
        end

        def has_child_elements?
          @spec[:child_elements].present?
        end

        def child_element_names
          @spec[:child_elements]
        end

        def validate_config_value(value)
          allow_values = @spec[:allow_values]
          if allow_values.present? && allow_values.include?(value)
            msg = "The value '#{value}' is not allowed. Allowed values: #{allow_values.inspect}."
            fail PatternValidationError, msg
          end
        end

        def default_config
          name = @spec[:name]
          value = @spec[:default_value]
          value ? {name => value} : {}
        end

        protected

        def find_spec(element_name)
          spec = @specs.find { |s| s[:element_name] == element_name }
          fail "Cannot find specification for element '#{element_name}'." if spec.nil?
          spec
        end

      end # End ConfigSpec class.

      def self.parse_configs(element, spec)
        configs = Hash.new
        config_name = spec.config_name
        if spec.has_child_elements?
          child_configs = Hash.new
          spec.child_element_names.each do |name|
            child_element = find_child_element(element, name)
            child_config_spec = spec.find(name)
            child_config = if child_element
                             parse_configs(child_element, child_config_spec)
                           else
                             child_config_spec.default_config
                           end
            child_configs.merge!(child_config)
          end
          configs[config_name]= child_configs
        else
          hash = xml_element_to_hash(element)
          config_value = hash[spec.element_name]
          spec.validate_config_value(config_value)
          configs[config_name]= config_value
        end

        configs
      end

      def initialize(configs)
        @configs = configs
      end

      def to_hash
        @configs
      end

    end
  end
end