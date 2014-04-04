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
require 'pattern_deployer/chef'
require 'pattern_deployer/deployer/base_deployer'
require 'pattern_deployer/deployer/topology_deployer'
require 'pattern_deployer/deployer/main_deployers_manager'
require 'pattern_deployer/deployer/state'
require 'pattern_deployer/errors'
require 'pattern_deployer/pattern'

module PatternDeployer
  module Deployer
    class MainDeployer < PatternDeployer::Deployer::BaseDeployer
      include PatternDeployer::Chef
      include PatternDeployer::Errors
      Pattern = PatternDeployer::Pattern::Pattern

      def initialize(topology)
        my_id = get_deployer_id(topology)
        super(my_id, nil, topology.topology_id, topology.owner.id)
      end

      def get_id
        deployer_id
      end

      def prepare_deploy(topology_xml, artifacts)
        lock_topology do
          reset
          initialize_child_deployers
          pattern = Pattern.new(topology_xml)
          # This will set the state of current deployer to 'DEPLOYING',
          # and call 'prepare_deployer' of each child deployer.
          super(pattern, artifacts)

          save
        end
      end

      def deploy
        # start a new thread to do the deployment
        @worker_thread = Thread.new do
          run(METHOD::DEPLOY)
        end
      end

      def prepare_scale(topology_xml, artifacts, nodes, diff)
        lock_topology do
          update
          initialize_child_deployers
          prepare_update_deployment
          pattern = Pattern.new(topology_xml)
          @topology_deployer.prepare_scale(pattern, artifacts, nodes, diff)

          save
        end
      end

      def scale
        # start a new thread to do the deployment
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          run(METHOD::SCALE)
        end
      end

      def prepare_repair(topology_xml, artifacts)
        lock_topology do
          update
          initialize_child_deployers
          prepare_update_deployment
          pattern = Pattern.new(topology_xml)
          @topology_deployer.prepare_repair(pattern, artifacts)

          save
        end
      end

      def repair
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          run(METHOD::REPAIR)
        end
      end

      def undeploy(topology_xml, artifacts)
        lock_topology do
          update
          initialize_child_deployers
          pattern = Pattern.new(topology_xml)
          super(pattern, artifacts)
        end
      end

      def list_nodes(topology_xml)
        lock_topology(:read_only => true) do
          update unless primary_deployer?

          if get_deploy_state != State::UNDEPLOY
            initialize_child_deployers
            pattern = Pattern.new(topology_xml)
            @topology_deployer.list_nodes(pattern)
          else
            Array.new
          end
        end
      end

      def get_state
        lock_topology(:read_only => true) do
          update unless primary_deployer?
          get_update_state == State::UNDEPLOY ? get_deploy_state : get_update_state
        end
      end

      protected

      module METHOD
        DEPLOY = :deploy
        SCALE = :scale
        REPAIR = :repair
      end

      def run(method)
        is_deploy = case method
                    when METHOD::DEPLOY then true
                    when METHOD::SCALE, METHOD::REPAIR then false
                    else
                      msg = "unexpected method #{method}"
                      raise InternalServerError.new(:message => msg)
                    end
        MainDeployersManager.instance.add_active_deployer(self)

        # Performs the actual 'run'.
        @topology_deployer.send(method)

        # Wait for completion of running and do error checking.
        raise DeploymentTimeoutError.new unless wait_to_finish
        raise get_children_error if failed?
        is_deploy ? on_deploy_success : on_update_success
      rescue Exception => e
        is_deploy ? on_deploy_failed(e.message) : on_update_failed(e.message)
        log e.message, e.backtrace #DEBUG
        raise e
      ensure
        MainDeployersManager.instance.delete_active_deployer(self)
      end

      def wait_to_finish(timeout = Rails.configuration.chef_max_deploy_time)
        start_time = Time.now
        while running? && !timeout?(start_time, timeout)
          sleep 60
        end
        timeout?(start_time, timeout) ? false : true
      end

      def get_deployer_id(topology)
        prefix = self.class.get_id_prefix
        user_id = topology.owner.id
        topology_id = topology.topology_id
        self.class.join(prefix, "user", user_id, "main", topology_id)
      end

      def initialize_child_deployers
        if @topology_deployer.nil?
          @topology_deployer = TopologyDeployer.new(self)
          self << @topology_deployer
        end
      end

      def update
        ChefNodesManager.instance.reload
        ChefClientsManager.instance.reload
        DatabagsManager.instance.reload
        super()
      end

      def running?
        @children.any? do |child|
          child.worker_thread_running?
        end
      end

      def timeout?(start_time, timeout)
        Time.now - start_time > timeout
      end

      def failed?
        get_children_state == State::DEPLOY_FAIL
      end

    end
  end
end