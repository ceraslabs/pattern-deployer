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
  module Artifact
    module Resource
      CREDENTIAL = "credential"
      KEY_PAIR = "identity_file"
      WAR_FILE = "war_file"
      SQL_SCRIPT = "sql_script_file"
    end

    module FileType
      IDENTITY_FILE = Resource::KEY_PAIR
      WAR_FILE = Resource::WAR_FILE
      SQL_SCRIPT_FILE = Resource::SQL_SCRIPT
    end

    class ResourceWrapper
      def initialize(resource, type, context)
        @resource = resource
        @type = type
        @context = context
        @selected = false
      end

      def resource_type
        @type
      end

      def get_id
        @resource[:id]
      end

      def select
        @selected = true
      end

      def selected?
        @selected
      end

      def owned_by_me?
        @resource.owner.id == get_current_user.id
      end

      def readable_by_me?
        resource = @resource
        @context.instance_eval{ can? :read, resource }
      end

      def get_current_user
        @context.instance_eval{ current_user }
      end

      def respond_to?(sym)
        @resource.respond_to?(sym) || super(sym)
      end

      def method_missing(sym, *args, &block)
        if @resource.respond_to?(sym)
          return @resource.send(sym, *args, &block)
        else
          super(sym, *args, &block)
        end
      end
    end

  end
end