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
require 'pattern_deployer/delegator'
require 'pattern_deployer/deployment_graph/edge'

module PatternDeployer
  module DeploymentGraph
    class DeploymentGraph
      module VertexState
        WAITING  = 1
        RUNNING  = 2
        SUCCESS = 3
        FAILED   = 4
      end

      class Vertex
        include VertexState
        include PatternDeployer::Delegator

        attr_accessor :deployer

        def initialize(node_deployer, graph)
          self.deployer = node_deployer
          @edges = Array.new
          @graph = graph
          set_state(SUCCESS)

          delegator_of(node_deployer)
        end

        def get_edge(other, type)
          all_edges(type).find { |edge| edge.connect_to == other }
        end

        def ==(other)
          fail "Unexpected type of vertex: #{other.class}." unless other.kind_of?(self.class)
          get_id == other.get_id
        end

        def eql?(other)
          self == other
        end

        def hash
          get_id.hash
        end

        def connect(other, type, data = nil)
          if connected?(other, type)
            log "The vertex #{get_name} has already connected to vertex #{other.get_name}."
            return
          end

          edge = Edge.new(self, other, type)
          edge.set_data(data) if data
          @edges << edge
        end

        def disconnect(other, type)
          all_edges(type).each do |edge|
            delete_edge(edge) if edge.connect_to == other
          end
        end

        def connected?(other, type = nil)
          all_edges(type).any? { |edge| edge.connect_to == other }
        end

        def success?
          @state == SUCCESS
        end

        def finished?
          @state == FAILED || @state == SUCCESS
        end

        def depending_vertex_failed?
          waiting? && get_depending_vertices.any? { |v| v.deployer.deploy_failed? }
        end

        def on_success
          set_state(SUCCESS)
        end

        def on_failed
          set_state(FAILED)
        end

        def on_depending_vertex_failed
          set_state(FAILED)
          deployer.on_deploy_not_started
        end

        def set_state(state)
          @state = state
        end

        def can_deploy?
          waiting? && get_depending_vertices.all? { |v| v.deployer.deploy_success? }
        end

        def deploy
          deployer.deploy
          set_state(RUNNING)
        end

        def can_update?
          waiting? && deployer.deploy_finished?
        end

        def update_deployment
          deployer.update_deployment
          set_state(RUNNING)
        end

        def notify_adjacent_vertices(key, value, connect_type = nil)
          each_edge(connect_type) { |edge| edge.notify(key, value) }
        end

        def each_edge(type = nil, &block)
          all_edges(type).each(&block)
        end

        protected

        def waiting?
          @state == WAITING
        end

        def delete_edge(edge)
          edge.delete
          @edges.delete(edge)
        end

        def get_depending_vertices
          @graph.get_depending_vertices(self)
        end

        def all_edges(type = nil)
          @edges.select { |edge| type.nil? || type == edge.type }
        end

      end
    end
  end
end