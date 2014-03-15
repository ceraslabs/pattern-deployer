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
module PatternDeployer
  module Utils
    module Xml
      def attribute_element?(element)
        raise "Unexpected node type for element #{element}" unless element.element?
        return false if element.attributes?

        if not has_element_children?(element)
          if element.children.size == 0 || (element.children.size == 1 && element.child.text?)
            return true
          else
            return false
          end
        end

        element.each_element do |child_element|
          return false if not attribute_element?(child_element)
        end
        true
      end

      def to_attribute(element)
        hash = Hash.new
        if element.children.size == 0
          hash[element.name] = true
        elsif element.children.size == 1 && element.child.text?
          hash[element.name] = element.content
        else
          sub_hash = Hash.new
          element.each_element do |child_element|
            sub_hash[child_element.name] = child_element.content
          end
          hash[element.name]= sub_hash
        end
        hash
      end

      def has_element_children?(element)
        element.children.any? do |child_element|
          child_element.element?
        end
      end

    end
  end
end