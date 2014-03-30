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

module PatternDeployer
  module Utils
    module Xml
      def hash_format?(element)
        unless element.element?
          msg = "Unexpected element: #{element}"
          raise InternalServerError.new(:message => msg)
        end

        return false if element.attributes?

        if has_child_element?(element)
          element.each_element do |child_element|
            return false if not hash_format?(child_element)
          end
          true
        else
          key_value_format?(element)
        end
      end

      def xml_element_to_hash(element)
        hash = Hash.new
        if key_value_format?(element)
          hash[element.name] = element.content
        else
          sub_hash = Hash.new
          element.each_element do |child_element|
            sub_hash[child_element.name] = xml_element_to_hash(child_element)
          end
          hash[element.name]= sub_hash
        end
        hash
      end

      def has_child_element?(element)
        element.children.any? do |child_element|
          child_element.element?
        end
      end

      def key_value_format?(element)
        element.children.size == 1 && element.child.text?
      end

    end
  end
end