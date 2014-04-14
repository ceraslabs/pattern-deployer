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
require 'pattern_deployer/deployment_graph/edge'
require 'pattern_deployer/deployment_graph/vertex'
require 'pattern_deployer/errors'

module PatternDeployer
  module DeploymentGraph
    class DeploymentGraph
      include PatternDeployer::Errors

      attr_reader :new_vertices, :dirty_vertices, :deleted_vertices

      def initialize(topology_deployer)
        @vertices = Hash.new
        @new_vertices = Set.new
        @dirty_vertices = Set.new
        @deleted_vertices = Set.new

        topology_deployer.node_deployers.each { |deployer| create_vertex(deployer) }
        establish_connections(topology_deployer.pattern)
      end

      def create_more_vertices(deployers)
        deployers.each { |deployer| create_vertex(deployer) }

        # Setup edges within new vertices.
        new_vertices.each do |v1|
          new_vertices.each do |v2|
            next if v1 == v2

            p1 = get_primary_vertex(v1)
            p2 = get_primary_vertex(v2)
            Edge.types.each do |edge_type|
              v1.connect(v2, edge_type) if p1.connected?(p2, edge_type)
            end
          end
        end

        # Setup edges between new vertices and existing vertices.
        scaling_clusters = new_vertices.map { |new_vertex| new_vertex.cluster }
        new_vertices.each do |new_vertex|
          pivot = get_primary_vertex(new_vertex)
          all_vertices.each do |vertex|
            next if scaling_clusters.include?(vertex.cluster)

            Edge.types.each do |type|
              # Connect vertex to new_vertex if appropriate.
              if vertex.connected?(pivot, type)
                data = vertex.get_edge(pivot, type).get_data
                vertex.connect(new_vertex, type, data)
              end
              # Connect new_vertex to vertex if appropriate.
              if pivot.connected?(vertex, type)
                new_vertex.connect(vertex, type)
                add_dirty_vertex(vertex)
              end
            end
          end
        end
      end

      def delete_vertices(deployers)
        deployers.each do |deployer|
          vertex = @vertices.delete(deployer.get_name)
          deleted_vertices << vertex
        end

        # Remove the edges that connect to the deleted vertices.
        scaling_clusters = new_vertices.map { |new_vertex| new_vertex.cluster }
        deleted_vertices.each do |deleted_vertex|
          all_vertices.each do |vertex|
            next if scaling_clusters.include?(vertex.cluster)

            Edge.types.each do |type|
              next unless deleted_vertex.connected?(vertex, type)
              deleted_vertex.disconnect(vertex, type)
              add_dirty_vertex(vertex)
            end
          end
        end
      end

      def update
        new_vertices.each do |vertex|
          vertex.on_success if vertex.deployer.deploy_success?
          vertex.on_failed if vertex.deployer.deploy_failed?
          vertex.on_depending_vertex_failed if vertex.depending_vertex_failed?
        end

        dirty_vertices.each do |vertex|
          vertex.on_success if vertex.deployer.update_success?
          vertex.on_failed if vertex.deployer.update_failed?
        end
      end

      def vertices_ready_to_deploy
        new_vertices.select { |vertex| vertex.can_deploy? }
      end

      def vertices_ready_to_update
        dirty_vertices.select { |vertex| vertex.can_update? }
      end

      def validate
        if circular_dependency?
          msg = "The topology cannot be deployed. Make sure nodes does not have circular dependencies."
          fail PatternValidationError, msg
        end
      end

      def deployment_finished?
        all_vertices.all? { |vertex| vertex.finished? }
      end

      def deployment_success?
        all_vertices.all? { |vertex| vertex.success? }
      end

      def get_depending_vertices(source_vertex)
        vertices = Set.new
        all_vertices.each do |vertex|
          next if vertex == source_vertex
          vertex.each_edge do |edge|
            vertices << vertex if edge.dependency? && edge.connect_to == source_vertex
          end
        end
        vertices
      end

      def on_data(key, value, vertex_name)
        vertex = @vertices[vertex_name]
        vertex.notify_adjacent_vertices(key, value)
      end

      protected

      def create_vertex(deployer)
        vertex = Vertex.new(deployer, self)
        @vertices[vertex.get_name] = vertex
        add_new_vertex(vertex) if new_vertex?(vertex)
        add_dirty_vertex(vertex) if dirty_vertex?(vertex)
      end

      def new_vertex?(vertex)
        return true if new_vertices.include?(vertex)
        deployer = vertex.deployer
        deployer.undeploy? || (deployer.deploy_failed? && !deployer.server_created?)
      end

      def dirty_vertex?(vertex)
        return true if dirty_vertices.include?(vertex)
        deployer = vertex.deployer
        deployer.update_failed? || (deployer.deploy_failed? && deployer.server_created?)
      end

      def add_new_vertex(vertex)
        vertex.set_state(Vertex::WAITING)
        new_vertices << vertex
      end

      def add_dirty_vertex(vertex)
        vertex.set_state(Vertex::WAITING)
        dirty_vertices << vertex
      end

      def establish_connections(pattern)
        # Load appserver-database relationships.
        pattern.get_database_connections.each do |conn|
          web_server = get_vertex(conn.web_server)
          database = get_vertex(conn.database)
          database.connect(web_server, :database_node)
        end

        # Load balancer-member relationships.
        pattern.get_balancer_memeber_connections.each do |conn|
          balancer = get_vertex(conn.load_balancer)
          member = get_vertex(conn.member)
          member.connect(balancer, :balancer_members)
        end

        # Load chef_client-chef_server relationships.
        pattern.get_chef_server_connections.each do |conn|
          chef_client = get_vertex(conn.chef_client)
          chef_server = get_vertex(conn.chef_server)
          chef_server.connect(chef_client, :chef_server)
        end

        # Load push metric relationships.
        pattern.get_mon_server_connections.each do |conn|
          monitor_client = get_vertex(conn.monitoring_client)
          monitor_server = get_vertex(conn.monitoring_server)
          monitor_client.connect(monitor_server, :monitor_clients)
        end
      end

      def get_primary_vertex(vertex)
        name = vertex.get_name.sub(/\d+$/, "1")
        get_vertex(name)
      end

      def circular_dependency?
        # check circular dependencies by using breadth first search algorithm
        all_vertices.each do |source|
          visited = Set.new
          queue = Queue.new
          visited << source
          queue << source
          until queue.empty? do
            vertex = queue.pop
            get_depending_vertices(vertex).each do |other|
              next if vertex == other # Skip self dependency.

              # A circle is detected.
              return true if vertex == source

              unless visited.include?(other)
                visited << other
                queue << other
              end
            end
          end
        end

        false
      end

      def all_vertices
        @vertices.values
      end

      def get_vertex(name)
        @vertices[name]
      end

    end
  end
end