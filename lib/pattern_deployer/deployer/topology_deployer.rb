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
require 'pattern_deployer/deployer/operation'
require 'pattern_deployer/deployer/state'
require 'pattern_deployer/deployment_graph'
require 'pattern_deployer/pattern'
require 'ostruct'

module PatternDeployer
  module Deployer
    class TopologyDeployer < PatternDeployer::Deployer::BaseDeployer
      include PatternDeployer::Artifact
      include PatternDeployer::Chef
      include PatternDeployer::Pattern

      DeploymentGraph = PatternDeployer::DeploymentGraph::DeploymentGraph

      attr_reader :pattern, :artifacts

      alias_method :node_deployers, :get_children

      def initialize(parent_deployer)
        my_id = create_deployer_id(parent_deployer)
        super(my_id, parent_deployer)
      end

      def set_fields(pattern, artifacts = nil)
        @pattern = pattern
        @artifacts = artifacts if artifacts
      end

      def get_id
        deployer_id
      end

      def prepare_deploy(pattern, artifacts)
        reset
        set_fields(pattern, artifacts)
        initialize_child_deployers(Operation::DEPLOY)
        @graph = DeploymentGraph.new(self)
        @graph.validate
        super()

        save_all
      end

      def deploy
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          run(Operation::DEPLOY)
        end
      end

      def prepare_scale(pattern, artifacts, nodes, diff)
        update
        set_fields(pattern, artifacts)
        initialize_child_deployers(Operation::SCALE)
        @graph = DeploymentGraph.new(self)
        if diff > 0
          deployers = create_more_deployers(nodes, diff)
          @graph.create_more_vertices(deployers)
          @graph.new_vertices.each { |vertex| vertex.deployer.prepare_deploy }
          @graph.dirty_vertices.each { |vertex| vertex.deployer.prepare_update_deployment }
        elsif diff < 0
          deployers = delete_deployers(nodes, -diff)
          @graph.delete_vertices(deployers)
          @graph.deleted_vertices.each { |vertex| vertex.deployer.undeploy }
          @graph.dirty_vertices.each { |vertex| vertex.deployer.prepare_update_deployment }
        else
          fail "There is nothing to scale."
        end
        @graph.validate
        prepare_update_deployment

        # save everything above
        save_all
      end

      def scale
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          run(Operation::SCALE)
        end
      end

      def prepare_repair(pattern, artifacts)
        update
        set_fields(pattern, artifacts)
        initialize_child_deployers(Operation::REPAIR)
        @graph = DeploymentGraph.new(self)
        @graph.new_vertices.each { |vertex| vertex.deployer.prepare_deploy }
        @graph.dirty_vertices.each { |vertex| vertex.deployer.prepare_update_deployment }
        @graph.validate

        # save everything above
        save_all
      end

      def repair
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          run(Operation::REPAIR)
        end
      end

      def update_deployment
        fail "Not implemented."
      end

      def undeploy(pattern, artifacts)
        update
        set_fields(pattern, artifacts)
        initialize_child_deployers(Operation::UNDEPLOY)

        # This call undeploys the topology by undeploying all its nodes.
        super()

        @pattern = nil
        @artifacts = nil
        @graph = nil
      end

      def list_nodes(pattern)
        update_if_needed
        set_fields(pattern)
        initialize_child_deployers(Operation::LIST)

        node_deployers.map do |deployer|
          node = OpenStruct.new
          node.name          = deployer.get_name
          node.server_ip     = deployer.get_server_ip
          node.services      = deployer.services
          node.status        = deployer.get_update_state == State::UNDEPLOY ? deployer.get_deploy_state : deployer.get_update_state
          node.is_app_server = deployer.application_server?
          node.app_name      = deployer.get_app_name
          node.app_url       = deployer.get_app_url
          node.is_db_server  = deployer.database_server?
          node.db_system     = deployer.get_db_system
          node.db_user       = deployer.get_db_user
          node.db_pwd        = deployer.get_db_pwd
          node.db_admin_user = deployer.get_db_admin_user
          node.db_admin_pwd  = deployer.get_db_admin_pwd
          node.is_monitoring_server = deployer.monitoring_server?
          node.monitoring_server_url = deployer.monitoring_server_url
          node
        end
      end

      def on_data(key, value, source)
        @graph.on_data(key, value, source)
      end

      protected

      def initialize_child_deployers(operation)
        case operation
        when Operation::DEPLOY
          reset_children = true
        when Operation::SCALE
          update_children = true
        when Operation::REPAIR
          fix_children = true
        when Operation::UNDEPLOY
          update_children = true
        when Operation::LIST
          update_children = true unless topology_locked_by_me?
        else
          fail "Unexpected operation #{operation}."
        end

        child_deployers = Array.new
        pattern.get_nodes.each do |node|
          node_info = pattern.get_node_info(node)
          services = pattern.get_services(node)
          web_server_configs = pattern.get_web_server_configs(node)
          database_configs = pattern.get_database_configs(node)

          pattern.get_all_copies(node).each do |deployer_name|
            child = get_child_deployer(deployer_name)
            child = ChefNodeDeployer.new(deployer_name, self) if child.nil?
            if reset_children
              child.reset
              child.set_fields(node_info, services, artifacts)
            elsif update_children
              child.update
              child.set_fields(node_info, services, artifacts)
            elsif fix_children
              child.update
              child.reset unless child.server_created?
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

      def run(operation)
        is_deploy = case operation
                    when Operation::DEPLOY then true
                    when Operation::SCALE, Operation::REPAIR then false
                    else fail "Unexpected operation #{operation}."
                    end

        loop do
          @graph.update
          @graph.vertices_ready_to_deploy.each { |vertex| vertex.deploy }
          @graph.vertices_ready_to_update.each { |vertex| vertex.update_deployment }

          if @graph.deployment_finished?
            success = @graph.deployment_success?
            if is_deploy
              success ? on_deploy_success : on_deploy_failed(get_children_error)
            else
              success ? on_update_success : on_update_failed(get_children_error)
            end
            break
          end

          # Scan the topology every 10 second.
          sleep 10
        end # end loop
      rescue Exception => e
        log e.message, e.backtrace # DEBUG
        # Eat the exception here because an unhandled exception may abort the main program.
      end

      def create_more_deployers(nodes, how_many)
        new_deployers = Array.new
        nodes.each do |node|
          template = get_deployer_template(node)
          num_of_copies = pattern.get_num_of_copies(node)
          (num_of_copies + 1 .. num_of_copies + how_many).each do |rank|
            name = self.class.join(node, rank)
            deployer = ChefNodeDeployer.create(name, template)
            new_deployers << deployer
          end
        end

        new_deployers
      end

      def delete_deployers(nodes, how_many)
        deleted_deployers = Array.new
        nodes.each do |node|
          num_of_copies = pattern.get_num_of_copies(node)
          (num_of_copies - how_many + 1 .. num_of_copies).each do |rank|
            name = self.class.join(node, rank)
            deployer = delete_child_deployer(name)
            deleted_deployers << deployer
          end
        end

        deleted_deployers
      end

      def get_deployer_template(node)
        name = self.class.join(node, 1)
        get_child_deployer(name)
      end

      def save_all
        self.save
        get_children.each { |child| child.save }
        # Save cookbook.
        if get_deploy_state == State::DEPLOYING
          cookbook_name = Rails.configuration.chef_cookbook_name
          cookbook = ChefCookbookWrapper.create(cookbook_name)
          cookbook.save
        end
      end

      def create_deployer_id(parent_deployer)
        self.class.join(self.class.get_id_prefix, "user", parent_deployer.topology_owner_id, "topology", parent_deployer.topology_id)
      end

    end
  end
end