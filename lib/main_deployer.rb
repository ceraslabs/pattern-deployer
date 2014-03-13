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
require "base_deployer"
require "chef_client"
require "chef_databag"
require "chef_node"
require "my_errors"
require "topology_deployer"


class MainDeployer < BaseDeployer

  def initialize(topology)
    my_id = self.class.join(self.class.get_id_prefix, "user", topology.owner.id, "main", topology.topology_id)
    super(my_id, nil, topology.topology_id, topology.owner.id)
  end

  def get_id
    deployer_id
  end

  def prepare_deploy(topology_xml, resources)
    lock_topology do
      self.reset
      self.deploy_state = State::DEPLOYING

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology)
      @topology_deployer.prepare_deploy(topology, resources)

      self.save
    end
  end

  def deploy
    DeployersManager.instance.add_active_deployer(self.deployer_id, self)

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
        DeployersManager.instance.delete_active_deployer(self.deployer_id)
      end
    end
  end

  def prepare_scale(topology_xml, resources, nodes, diff)
    lock_topology do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology)

      prepare_update_deployment
      @topology_deployer.prepare_scale(topology, resources, nodes, diff)

      self.save
    end
  end

  def scale
    DeployersManager.instance.add_active_deployer(self.deployer_id, self)

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
        DeployersManager.instance.delete_active_deployer(self.deployer_id)
      end
    end
  end

  def prepare_repair(topology_xml, resources)
    lock_topology do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology)

      prepare_update_deployment
      @topology_deployer.prepare_repair(topology, resources)

      self.save
    end
  end

  def repair
    DeployersManager.instance.add_active_deployer(self.deployer_id, self)

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
        DeployersManager.instance.delete_active_deployer(self.deployer_id)
      end
    end
  end

  def undeploy(topology_xml, resources)
    lock_topology do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology)

      @topology_deployer.undeploy(topology, resources)
      @topology_deployer = nil

      self.save
    end
  end

  def list_nodes(topology_xml)
    lock_topology(:read_only => true) do
      self.reload unless self.primary_deployer?

      if get_deploy_state != State::UNDEPLOY
        topology = TopologyWrapper.new(topology_xml)
        initialize_deployers(topology)
        raise "Unexpected missing of topology deployer" unless @topology_deployer
        return @topology_deployer.list_nodes(topology)
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

  def initialize_deployers(topology, options={})
    resources = options[:resources]

    if @topology_deployer.nil?
      @topology_deployer = TopologyDeployer.new(self)
      self << @topology_deployer
    end
  end

end