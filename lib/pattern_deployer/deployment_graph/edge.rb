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
  module DeploymentGraph
    class DeploymentGraph
      class Edge
        attr_reader :type

        TYPES_OF_EDGE = [:database_node, :balancer_members, :chef_server, :monitor_clients]

        def self.create(source, sink, template)
          edge = new(source, sink, template.type)
          edge.set_data(template.data)
          edge
        end

        def self.types
          TYPES_OF_EDGE
        end

        def initialize(source, sink, type)
          validate_type(type)

          @source = source
          @sink = sink
          @type = type

          # TODO reverse direction.
          sink[type] ||= Array.new
          sink[type] << source.get_id unless sink[type].include?(source.get_id)
        end

        def connect_from
          @source
        end

        def connect_to
          @sink
        end

        def notify(key, value)
          @sink[@source.get_id] ||= Hash.new
          if @sink[@source.get_id][key].nil?
            @sink[@source.get_id][key] = value
            @sink.save
          end
        end

        def delete
          @sink[type].delete(@source.get_id) if @sink[type]
          @sink.delete_key(@source.get_id)
        end

        def dependency?
          [:chef_server].include?(type)
        end

        def get_data
          @sink[@source.get_id] || Hash.new
        end

        def set_data(data)
          @sink[@source.get_id] = data.deep_dup if data
        end

        protected

        def validate_type(type)
          fail "Unexpected type of edge '#{type}'." unless self.class.types.include?(type)
        end

      end
    end
  end
end