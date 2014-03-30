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
require 'pattern_deployer/deployer/deployer_state'
require 'pattern_deployer/errors'
require 'pattern_deployer/pattern'

module PatternDeployer
  module Deployer
    class MainDeployer < PatternDeployer::Deployer::BaseDeployer
      include PatternDeployer::Chef
      include PatternDeployer::Errors
      Pattern = PatternDeployer::Pattern::Pattern

      def initialize(topology)
        my_id = self.class.join(self.class.get_id_prefix, "user", topology.owner.id, "main", topology.topology_id)
        super(my_id, nil, topology.topology_id, topology.owner.id)
      end

      def get_id
        deployer_id
      end

      def prepare_deploy(topology_xml, artifacts)
        lock_topology do
          self.reset
          self.deploy_state = State::DEPLOYING

          initialize_deployers
          pattern = Pattern.new(topology_xml)
          @topology_deployer.prepare_deploy(pattern, artifacts)

          self.save
        end
      end

      def deploy
        MainDeployersManager.instance.add_active_deployer(self.deployer_id, self)

        # start a new thread to do the deployment
        @worker_thread = Thread.new do
          begin
            # Check if the topology is deployable
            if @topology_deployer.deployable?
              err_msg = "The topology cannot be deployed. Make sure nodes does not have circular dependencies"
              raise DeploymentError.new(:message => err_msg)
            end

            # This will do the deployment
            super()

            # wait for deployment finish and do error checking
            unless wait
              raise "Deployment timeout"
            end

            raise get_children_error if get_children_state == State::DEPLOY_FAIL
            on_deploy_success
          rescue Exception => ex
            on_deploy_failed(ex.message)
            #debug
            puts ex.message
            puts ex.backtrace[0..10].join("\n")
          ensure
            MainDeployersManager.instance.delete_active_deployer(self.deployer_id)
          end
        end
      end

      def prepare_scale(topology_xml, artifacts, nodes, diff)
        lock_topology do
          self.reload

          initialize_deployers
          prepare_update_deployment
          pattern = Pattern.new(topology_xml)
          @topology_deployer.prepare_scale(pattern, artifacts, nodes, diff)

          self.save
        end
      end

      def scale
        MainDeployersManager.instance.add_active_deployer(self.deployer_id, self)

        # start a new thread to do the deployment
        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          begin
            @topology_deployer.scale
            unless wait
              raise "Deployment timeout"
            end
            raise get_children_error if get_children_state == State::DEPLOY_FAIL
            on_update_success
          rescue Exception => ex
            on_update_failed(ex.message)
            #debug
            puts ex.message
            puts ex.backtrace[0..10].join("\n")
          ensure
            MainDeployersManager.instance.delete_active_deployer(self.deployer_id)
          end
        end
      end

      def prepare_repair(topology_xml, artifacts)
        lock_topology do
          self.reload

          initialize_deployers
          prepare_update_deployment
          pattern = Pattern.new(topology_xml)
          @topology_deployer.prepare_repair(pattern, artifacts)

          self.save
        end
      end

      def repair
        MainDeployersManager.instance.add_active_deployer(self.deployer_id, self)

        @worker_thread.kill if @worker_thread
        @worker_thread = Thread.new do
          begin
            @topology_deployer.repair
            unless wait
              raise "Deployment timeout"
            end
            raise get_children_error if get_children_state == State::DEPLOY_FAIL
            on_update_success
          rescue Exception => ex
            on_update_failed(ex.message)
            #debug
            puts ex.message
            puts ex.backtrace[0..10].join("\n")
          ensure
            MainDeployersManager.instance.delete_active_deployer(self.deployer_id)
          end
        end
      end

      def undeploy(topology_xml, artifacts)
        lock_topology do
          self.reload

          initialize_deployers
          pattern = Pattern.new(topology_xml)
          @topology_deployer.undeploy(pattern, artifacts)
          @topology_deployer = nil

          self.save
        end
      end

      def list_nodes(topology_xml)
        lock_topology(:read_only => true) do
          self.reload unless self.primary_deployer?

          if get_deploy_state != State::UNDEPLOY
            initialize_deployers
            pattern = Pattern.new(topology_xml)
            return @topology_deployer.list_nodes(pattern)
          else
            return Array.new
          end
        end
      end

      def get_state
        lock_topology(:read_only => true) do
          self.reload unless self.primary_deployer?
          self.get_update_state == State::UNDEPLOY ? self.get_deploy_state : self.get_update_state
        end
      end

      def wait(timeout = Rails.configuration.chef_max_deploy_time)
        start_time = Time.now
        while running? && !timeout?(start_time, timeout)
          sleep 60
        end
        timeout?(start_time, timeout) ? false : true
      end

      def running?
        @children.any? do |child|
          child.worker_thread_running?
        end
      end

      def timeout?(start_time, timeout)
        Time.now - start_time > timeout
      end

      protected

      def reload
        ChefNodesManager.instance.reload
        ChefClientsManager.instance.reload
        DatabagsManager.instance.reload
        super()
      end

      def initialize_deployers
        if @topology_deployer.nil?
          @topology_deployer = TopologyDeployer.new(self)
          self << @topology_deployer
        end
      end

    end
  end
end