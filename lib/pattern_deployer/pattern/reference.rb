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
require 'xml'

module PatternDeployer
  module Pattern
    module ReferenceType
      USE_TEMPLATE = :use_template
      EXTEND_TEMPLATE = :extend_template
      LB_MEMBER = :lb_member
      DB_CONNECTION = :db_connection
      CHEF_SERVER = :chef_server
      MON_SERVER = :mon_server
    end

    class Reference
      METADATA = [
        {
          type:       ReferenceType::USE_TEMPLATE,
          element:    'use_template',
          attribute:  'name',
          refer_from: ['node'],
          refer_to:   'template'
        },
        {
          type:       ReferenceType::EXTEND_TEMPLATE,
          element:    'extend',
          attribute:  'template',
          refer_from: ['template'],
          refer_to:   'template'
        },
        {
          type:       ReferenceType::LB_MEMBER,
          element:    'member',
          attribute:  'node',
          refer_from: ['node', 'template'],
          refer_to:   'node'
        },
        {
          type:       ReferenceType::DB_CONNECTION,
          element:    'database_connection',
          attribute:  'node',
          refer_from: ['node', 'template'],
          refer_to:   'node'
        },
        {
          type:       ReferenceType::CHEF_SERVER,
          element:    'chef_server',
          attribute:  'node',
          refer_from: ['node', 'template'],
          refer_to:   'node'
        },
        {
          type:       ReferenceType::MON_SERVER,
          element:    'monitoring_server',
          attribute:  'node',
          refer_from: ['node', 'template'],
          refer_to:   'node'
        }
      ]

      def initialize(ref_element, metadata=nil)
        @ref_element = ref_element
        if metadata
          @metadata = metadata
        else
          @metadata = self.class.get_metadata(:element => ref_element.name)
        end
      end

      def self.all_references(ref_type, document)
        metadata = get_metadata(:type => ref_type)
        element_name = metadata[:element]
        attr = metadata[:attribute]
        document.find(".//#{element_name}[@#{attr}]").map do |ref_element|
          Reference.new(ref_element, metadata)
        end
      end

      def self.get_metadata(options = Hash.new)
        metadata = METADATA.find do |meta|
          if options[:type]
            meta[:type] == options[:type]
          elsif options[:element]
            meta[:element] = options[:element]
          else
            false
          end
        end

        if metadata
          metadata
        else
          fail "Cannot find metadata for with options #{options.inspect}."
        end
      end

      def self.reference?(element)
        METADATA.any? do |meta|
          meta[:element] == element.name
        end
      end

      def type
        @metadata[:type]
      end

      def refer_from
        element_refer_from['id']
      end

      def refer_to
        attr = @metadata[:attribute]
        @ref_element[attr]
      end

      def refer_from_template?
        element_refer_from.name == 'template'
      end

      def refer_from_node?
        element_refer_from.name == 'node'
      end

      def refer_to_template?
        @metadata[:refer_to] == 'template'
      end

      def refer_to_node?
        @metadata[:refer_to] == 'node'
      end

      def to_s
        @ref_element.to_s
      end

      protected

      def element_refer_from
        element = @ref_element.parent
        while !refer_from?(element)
          if element.parent?
            element = element.parent
          else
            fail "Cannot find the element refer from."
          end
        end
        element
      end

      def refer_from?(element)
        @metadata[:refer_from].include?(element.name)
      end

    end
  end
end