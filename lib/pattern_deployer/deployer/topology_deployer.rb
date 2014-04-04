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
require 'pattern_deployer/artifact'
require 'pattern_deployer/chef'
require 'pattern_deployer/deployer/base_deployer'
require 'pattern_deployer/deployer/chef_node_deployer'
require 'pattern_deployer/deployer/state'
require 'pattern_deployer/pattern'
require 'ostruct'

module PatternDeployer
  module Deployer
    # A graph to keep track of the run-time state of each nodes
    class TopologyDeployer < PatternDeployer::Deployer::BaseDeployer
      include PatternDeployer::Artifact
      include PatternDeployer::Chef
      include PatternDeployer::Errors
      include PatternDeployer::Pattern

      class Edge
        def initialize(from, to, type)
          validate_type!(type)

          @from = from
          @to = to
          @type = type

          to[type] ||= Array.new
          to[type] << from.get_id unless to[type].include?(from.get_id)
          to[from.get_id] ||= Hash.new
        end

        def get_source
          @from
        end

        def get_destination
          @to
        end

        def get_type
          @type
        end

        def notify(key, value)
          @to[@from.get_id][key.to_s] = value
          @to.save
        end

        def each_notification(&block)
          @to[@from.get_id].each(&block)
        end

        def delete
          @to[get_type].delete(@from.get_id) if @to.key?(get_type) && @to[get_type].include?(@from.get_id)
          @to.delete_key(@from.get_id) if @to.key?(@from.get_id)
        end

        def self.types
          @@valid_types
        end

        protected

        @@valid_types = [:database_node, :balancer_members, :chef_server, :monitor_clients]

        def validate_type!(type)
          raise "Unexpected type of edge #{type}" unless @@valid_types.include?(type)
        end
      end #class Edge

      class Vertex
        WAITING     = 1 if not defined?(WAITING)
        RUNNING     = 2 if not defined?(RUNNING)
        FINISHED    = 3 if not defined?(FINISHED)
        FAILED      = 4 if not defined?(FAILED)

        def initialize(name, node_deployer, topology_deployer)
          @edges = Array.new
          @name = name
          @state = WAITING
          @deployer = node_deployer
          @topology_deployer = topology_deployer
        end

        def get_name
          return @name
        end

        def each_edge(type = nil, &block)
          get_edges(type).each(&block)
        end

        def get_edges(type = nil)
          @edges.select do |edge|
            type.nil? || type == edge.get_type
          end
        end

        def delete_edge(edge)
          edge.delete
          @edges.delete(edge)
        end

        def ==(vertex)
          raise "Unexpected type of vertex: #{vertex.class}" if vertex.class != Vertex
          raise "get_id return nil" if self.get_id.nil? || vertex.get_id.nil?
          return self.get_id == vertex.get_id
        end

        def connect(vertex, type)
          self.each_edge(type) do |edge|
            return edge if edge.get_destination == vertex
          end

          new_edge = Edge.new(self, vertex, type)
          @edges << new_edge
          new_edge
        end

        def disconnect(vertex, type)
          self.get_edges(type).each do |edge|
            self.delete_edge(edge) if edge.get_destination == vertex
          end
        end

        def get_connection(vertex, type = nil)
          self.get_edges(type).find do |edge|
            edge.get_destination == vertex
          end
        end

        def connected?(vertex, type = nil)
          self.get_edges(type).any? do |edge|
            edge.get_destination == vertex
          end
        end

        def get_state
          @state
        end

        def get_deployer
          @deployer
        end

        def deploy_success?
          @deployer.get_deploy_state == State::DEPLOY_SUCCESS
        end

        def on_success
          @state = FINISHED
        end

        def deploy_failed?
          @deployer.get_deploy_state == State::DEPLOY_FAIL
        end

        def on_failed
          @state = FAILED
        end

        def update_success?
          @deployer.get_update_state == State::DEPLOY_SUCCESS
        end

        def update_failed?
          @deployer.get_update_state == State::DEPLOY_FAIL
        end

        def can_start?
          if @state == WAITING
            return get_depending_vertice.all?{|parent| parent.get_deploy_state == State::DEPLOY_SUCCESS}
          else
            return false
          end
        end

        def start
          @deployer.deploy
          @state = RUNNING
        end

        def can_update?
          @state == WAITING && (@deployer.get_deploy_state == State::DEPLOY_SUCCESS ||
                                @deployer.get_deploy_state == State::DEPLOY_FAIL)
        end

        def update
          @deployer.update_deployment
          @state = RUNNING
        end

        def depending_vertex_failed?
          if @state == WAITING
            return get_depending_vertice.any?{|parent| parent.get_deploy_state == State::DEPLOY_FAIL}
          else
            return false
          end
        end

        def on_depending_vertex_failed
          @state = FAILED
          @deployer.set_deploy_state(State::UNDEPLOY)
        end

        def notify_adjacent_vertice(key, value, connect_type = nil)
          self.each_edge(connect_type) do |edge|
            edge.notify(key, value)
          end
        end

        def get_depending_vertice
          # list of types of edges that indicate dependencies between vertice
          target_types = [:chef_server]

          vertice = Array.new
          @topology_deployer.all_vertice.each do |vertex|
            next if vertex == self || vertice.include?(vertex)
            vertex.each_edge do |edge|
              vertice << vertex if target_types.include?(edge.get_type) && edge.get_destination == self
            end
          end
          vertice
        end

        def prepare_update_deployment
          @deployer.prepare_update_deployment
          @state = WAITING
        end

        def respond_to?(sym)
          @deployer.respond_to?(sym) || super(sym)
        end

        def method_missing(sym, *args, &block)
          if @deployer.respond_to?(sym)
            return @deployer.send(sym, *args, &block)
          else
            super(sym, *args, &block)
          end
        end
      end #class Vertex


      attr_accessor :pattern, :artifacts

      def initialize(parent_deployer)
        my_id = self.class.join(self.class.get_id_prefix, "user", parent_deployer.topology_owner_id, "topology", parent_deployer.topology_id)
        super(my_id, parent_deployer)
      end

      def set_fields(pattern, artifacts = nil)
        self.pattern = pattern
        self.artifacts = artifacts if artifacts
      end

      def get_id
        deployer_id
      end

      def validate_deployment!
        if circular_dependency?
          msg = "The topology cannot be deployed. Make sure nodes does not have circular dependencies"
          raise XmlValidationError.new(:message => msg)
        end
      end

      def circular_dependency?
        # check circular dependencies by using breadth first search algorithm
        has_circle = false
        @vertice.each do |vertex_name, vertex|
          visited = Set.new
          queue = Queue.new

          visited << vertex_name
          queue << vertex

          until queue.empty? do
            v = queue.pop
            v.get_depending_vertice.each do |c|
              next if v.get_id == c.get_id # skip self reference
              has_circle = true if c.get_name == vertex_name
              unless visited.include?(c.get_name)
                visited << c.get_name
                queue << c
              end
            end
          end
        end

        has_circle
      end

      def prepare_deploy(pattern, artifacts)
        reset
        set_fields(pattern, artifacts)
        initialize_deployment_graph(:reset_children => true)
        establish_connection
        validate_deployment!

        super()

        save_all
      end

      def deploy
        @worker_thread = Thread.new do
          deploy_helper(:action => :deploy, :new_vertice => all_vertice)
        end
      end

      def prepare_scale(pattern, artifacts, nodes, diff)
        update
        set_fields(pattern, artifacts)
        initialize_deployment_graph
        establish_connection

        @new_vertice = Hash.new
        @dirty_vertice = Hash.new
        if diff > 0
          @new_vertice = create_more_vertices(pattern, artifacts, nodes, diff)
          @new_vertice.each_value{|vertex| vertex.prepare_deploy}
          @dirty_vertice = setup_vertice(@new_vertice, nodes)
          @vertice.merge!(@new_vertice)
        elsif diff < 0
          vertice_to_delete = get_vertice_to_delete(pattern, nodes, -diff)
          @dirty_vertice = delete_vertice(vertice_to_delete, nodes)
          vertice_to_delete.each_value{|vertex| vertex.undeploy}
        else
          raise "Unexpected diff"
        end

        prepare_update_deployment
        @dirty_vertice.each_value{|vertex| vertex.prepare_update_deployment}

        # save everything above
        save_all
      end

      def scale
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          deploy_helper(:action => :update_deployment,
                        :new_vertice => @new_vertice.values,
                        :dirty_vertice => @dirty_vertice.values)
        end
      end

      def prepare_repair(pattern, artifacts)
        update
        set_fields(pattern, artifacts)
        initialize_deployment_graph
        establish_connection

        @new_vertice = Hash.new
        @dirty_vertice = Hash.new
        @vertice.each do |vertex_name, vertex|
          deployer = vertex.get_deployer
          if deployer.undeploy? || (deployer.deploy_failed? && !deployer.server_created?)
            deployer.reset
            @new_vertice[vertex_name] = vertex
          end

          if (deployer.deploy_failed? && deployer.server_created?) || deployer.update_failed?
            @dirty_vertice[vertex_name] = vertex
          end
        end

        prepare_update_deployment
        @new_vertice.each_value{|vertex| vertex.prepare_deploy}
        @dirty_vertice.each_value{|vertex| vertex.prepare_update_deployment}

        # save everything above
        save_all
      end

      def repair
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          deploy_helper(:action => :update_deployment,
                        :new_vertice => @new_vertice.values,
                        :dirty_vertice => @dirty_vertice.values)
        end
      end

      def update_deployment
        raise "NOT IMPLEMENT"
      end

      def undeploy(pattern, artifacts)
        update
        set_fields(pattern, artifacts)
        initialize_child_deployers

        super()
        self.pattern = nil
        self.artifacts = nil
        @vertice = nil
      end

      def list_nodes(pattern)
        update unless primary_deployer?
        set_fields(pattern)
        initialize_child_deployers(:update_children => !primary_deployer?)

        get_children.map do |child|
          node = OpenStruct.new
          node.name          = child.get_pretty_name
          node.server_ip     = child.get_server_ip
          node.services      = child.services
          node.status        = child.get_update_state == State::UNDEPLOY ? child.get_deploy_state : child.get_update_state
          node.is_app_server = child.application_server?
          node.app_name      = child.get_app_name
          node.app_url       = child.get_app_url
          node.is_db_server  = child.database_server?
          node.db_system     = child.get_db_system
          node.db_user       = child.get_db_user
          node.db_pwd        = child.get_db_pwd
          node.db_admin_user = child.get_db_admin_user
          node.db_admin_pwd  = child.get_db_admin_pwd
          node.is_monitoring_server = child.monitoring_server?
          node.monitoring_server_url = child.monitoring_server_url
          node
        end
      end

      def on_data(key, value, vertex_name)
        vertex = @vertice[vertex_name]
        if key == :public_ip || key == :private_ip
          vertex.notify_adjacent_vertice(key, value)
        end
      end

      def all_vertice
        @vertice.values
      end


      protected

      def initialize_deployment_graph(options={})
        initialize_child_deployers(options)
        @vertice = Hash.new
        get_children.map do |child|
          @vertice[child.get_name] = Vertex.new(child.get_name, child, self)
        end
      end

      def initialize_child_deployers(options={})
        reset_children = options.key?(:reset_children) ? options[:reset_children] : false
        update_children = options.key?(:update_children) ? options[:update_children] : true

        child_deployers = Array.new
        pattern.get_nodes.each do |node_id|
          node_info = pattern.get_node_info(node_id)
          services = pattern.get_services(node_id)
          web_server_configs = pattern.get_web_server_configs(node_id)
          database_configs = pattern.get_database_configs(node_id)

          pattern.get_all_copies(node_id).each do |deployer_name|
            child = get_child_by_name(deployer_name)
            child = ChefNodeDeployer.new(deployer_name, self) if child.nil?
            if reset_children
              child.reset
              child.set_fields(node_info, services, artifacts)
            elsif update_children
              child.update
              child.set_fields(node_info, services, artifacts)
            else
              child.set_fields_if_not_before(node_info, services, artifacts)
            end
            child.set_web_server_configs(web_server_configs) if web_server_configs
            child.set_database_configs(database_configs) if database_configs

            child_deployers << child
          end
        end

        @children = child_deployers
      end

      def deploy_helper(options)
        action = options[:action] || :deploy

        if action == :deploy
          new_vertice = options[:new_vertice] || Hash.new
          dirty_vertice = Array.new
        elsif action == :update_deployment
          new_vertice = options[:new_vertice] || Hash.new
          dirty_vertice = options[:dirty_vertice] || Hash.new
        else
          raise "Unexpected action #{action}"
        end

        while true
          new_vertice.each do |vertex|
            vertex.on_success if vertex.deploy_success?
            vertex.on_failed if vertex.deploy_failed?
          end

          dirty_vertice.each do |vertex|
            vertex.on_success if vertex.update_success?
            vertex.on_failed if vertex.update_failed?
          end

          deployment_finished, deployment_failed = try_deploy(new_vertice)
          if action == :update_deployment
            finished, failed = try_deploy(dirty_vertice, :action => :update_vertice)
            deployment_finished &&= finished
            deployment_failed ||= failed
          end

          # exit if all the nodes finished
          if deployment_finished
            if action == :deploy
              deployment_failed ? on_deploy_failed(get_children_error) : on_deploy_success
            elsif action == :update_deployment
              deployment_failed ? on_update_failed(get_children_error) : on_update_success
            else
              raise "Unexpected action #{action}"
            end

            break
          end

          # scan the topology every 10 second
          sleep 10
        end #while
      rescue Exception => ex
        #debug
        puts ex.message
        puts ex.backtrace[0..10].join("\n")
      end

      def try_deploy(vertice, options={})
        action = options[:action] || :deploy_vertice

        finished = true
        failed = false
        vertice.each do |vertex|
          if action == :deploy_vertice
            vertex.start if vertex.can_start?
          elsif action == :update_vertice
            vertex.update if vertex.can_update?
          else
            raise "Unexpected action #{action}"
          end
          vertex.on_depending_vertex_failed if vertex.depending_vertex_failed?

          finished = false if vertex.get_state == Vertex::WAITING || vertex.get_state == Vertex::RUNNING
          failed = true if vertex.get_state == Vertex::FAILED
        end

        return finished, failed
      end

      def create_more_vertices(pattern, artifacts, nodes, how_many)
        new_vertice = Hash.new
        nodes.each do |node_id|
          node_info = pattern.get_node_info(node_id)
          services = pattern.get_services(node_id)
          num_of_copies = pattern.get_num_of_copies(node_id)
          (num_of_copies + 1 .. num_of_copies + how_many).each do |rank|
            extended_node_id = self.class.join(node_id, rank)
            node_deployer = ChefNodeDeployer.new(extended_node_id, self)
            node_deployer.reset
            node_deployer.set_fields(node_info, services, artifacts)
            self << node_deployer
            new_vertex = Vertex.new(extended_node_id, node_deployer, self)
            load_vertice_data(new_vertex)
            new_vertice[extended_node_id] = new_vertex
          end
        end

        new_vertice
      end

      def setup_vertice(new_vertice, new_nodes)
        setup_internal_connection(new_vertice)

        # For nodes that are not candidates to scale, all their vertice are categorized as external.
        # We care if a vertex is external since it need to be setup and deployed differently.
        external_vertice = get_vertice_not_in_nodes(new_nodes)

        dirty_vertice = Hash.new
        new_vertice.each_value do |new_vertex|
          dirty_vertice.merge!(setup_external_connection(new_vertex, external_vertice))
        end
        dirty_vertice
      end

      def setup_internal_connection(new_vertice)
        new_vertice.each_value do |vertex1|
          new_vertice.each_value do |vertex2|
            next if vertex1 == vertex2
            Edge.types.each do |edge_type|
              vertex1_sample = get_sample_vertex(vertex1)
              vertex2_sample = get_sample_vertex(vertex2)
              vertex1.connect(vertex2, edge_type) if vertex1_sample.connected?(vertex2_sample, edge_type)
            end
          end
        end
      end

      def setup_external_connection(new_vertex, external_vertice)
        dirty_vertice = Hash.new
        sample_vertex = get_sample_vertex(new_vertex)
        external_vertice.each do |external_vertex|
          Edge.types.each do |edge_type|
            # For connection from external_vertex to sample_vertex, we do the following:
            # 1. Setup connection of the same type from external_vertex to new_vertex.
            # 2. Re-send the same set of notifications to new_vertex.
            if external_vertex.connected?(sample_vertex, edge_type)
              my_connection = external_vertex.connect(new_vertex, edge_type)
              external_vertex.get_connection(sample_vertex, edge_type).each_notification do |key, value|
                my_connection.notify(key, value)
              end
            end

            # For connection from sample_vertex to external_vertex, we do the following:
            # 1. Setup connection of the same type from new_vertex to external_vertex.
            # 2. The external_vertex need to be re-deploy so mark it as dirty.
            if sample_vertex.connected?(external_vertex, edge_type)
              new_vertex.connect(external_vertex, edge_type)
              dirty_vertice[external_vertex.get_name] = external_vertex
            end
          end
        end

        dirty_vertice
      end

      def load_vertice_data(new_vertex)
        sample_vertex = get_sample_vertex(new_vertex)
        ["port_redir", FileType::WAR_FILE, "database", FileType::SQL_SCRIPT_FILE, "credential_id",
         "war_file_id", "sql_script_file_id", "identity_file_id"].each do |attr_key|
          next if not sample_vertex.key?(attr_key)
          begin
            new_vertex[attr_key] = sample_vertex[attr_key].deep_dup
          rescue TypeError
            new_vertex[attr_key] = sample_vertex[attr_key]
          end
        end
      end

      def get_sample_vertex(new_vertex)
        name = new_vertex.get_name.sub(/\d+$/, "1")
        @vertice[name]
      end

      def get_vertice_to_delete(pattern, nodes, how_many)
        vertice_to_delete = Hash.new
        nodes.each do |node_id|
          num_of_copies = pattern.get_num_of_copies(node_id)
          (num_of_copies - how_many + 1 .. num_of_copies).each do |rank|
            vertex_name = self.class.join(node_id, rank)
            vertice_to_delete[vertex_name] = @vertice[vertex_name]
          end
        end

        vertice_to_delete
      end

      def delete_vertice(vertice, nodes)
        external_vertice = get_vertice_not_in_nodes(nodes)
        dirty_vertice = Hash.new
        vertice.each_value do |vertex_to_delete|
          external_vertice.each do |external_vertex|
            Edge.types.each do |edge_type|
              next unless vertex_to_delete.connected?(external_vertex, edge_type)
              vertex_to_delete.disconnect(external_vertex, edge_type)
              dirty_vertice[external_vertex.get_name] = external_vertex
            end
          end
          delete_vertex(vertex_to_delete)
        end

        dirty_vertice
      end

      def delete_vertex(vertex)
        @vertice.delete(vertex.get_name)
        self.delete_child(vertex.get_deployer)
      end

      def get_vertice_not_in_nodes(nodes)
        vertice = Array.new
        @vertice.each do |vertex_name, vertex|
          is_in = nodes.any? do |node_id|
            vertex_name.index(node_id) == 0
          end
          vertice << vertex unless is_in
        end
        vertice
      end

      def establish_connection
        #load appserver-database relationships
        pattern.get_database_connections.each do |conn|
          web_server = @vertice[conn.web_server]
          database = @vertice[conn.database]
          database.connect(web_server, :database_node)
        end

        #load balancer-member relationships
        pattern.get_balancer_memeber_connections.each do |conn|
          balancer = @vertice[conn.load_balancer]
          member = @vertice[conn.member]
          member.connect(balancer, :balancer_members)
        end

        #load chef_client-chef_server relationships
        pattern.get_chef_server_connections.each do |conn|
          chef_client = @vertice[conn.chef_client]
          chef_server = @vertice[conn.chef_server]
          chef_server.connect(chef_client, :chef_server)
        end

        #load push metric relationships
        pattern.get_mon_server_connections.each do |conn|
          monitor_client = @vertice[conn.monitoring_client]
          monitor_server = @vertice[conn.monitoring_server]
          monitor_client.connect(monitor_server, :monitor_clients)
        end
      end

      def save_all
        self.save
        get_children.each{ |child| child.save }
        #save cookbook
        if get_deploy_state == State::DEPLOYING
          cookbook_name = Rails.configuration.chef_cookbook_name
          cookbook = ChefCookbookWrapper.create(cookbook_name)
          cookbook.save
        end
      end

    end
  end
end