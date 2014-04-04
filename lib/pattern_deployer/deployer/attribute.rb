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
  module Deployer
    module Attribute
      module ClassMethods
        def attribute_accessor(*accessors)
          accessors.each do |name|
            name = name.to_s

            define_method(name) do
              attributes ? attributes[name] : nil
            end

            define_method("#{name}=") do |value|
              self.attributes ||= Hash.new
              value.nil? ? attributes.delete(name) : attributes[name] = value
            end
          end
        end
      end

      attr_accessor :attributes

      def self.included(base)
        base.extend(ClassMethods)
      end

    end
  end
end