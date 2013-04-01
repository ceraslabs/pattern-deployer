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
require "supporting_service_deployer"
require "topology_deployer"
require "migration_deployer"


class MainDeployer < BaseDeployer

  # This class is an abstraction of mapping between topology and supporting service
  # This mapping is many-to-many mapping, e.g. each topology can require any number of supporting service while every supporting service can be required by any number of topologies
  # If the deployment of a topology needs supporting service, it will consume supporting service through this class
  class MySupportingServiceDeployer < BaseDeployer
    def initialize(service_deployer, topology)
      id = [self.class.get_id_prefix, "topology", topology.get_topology_id, "service", service_deployer.get_service_name].join("_")
      super(id, topology.get_topology_id)

      @deployer = service_deployer
      @service_name = service_deployer.get_service_name
      @topology = topology
      @output = Queue.new
    end

    def get_id
      deployer_id
    end

    def get_service_name
      @service_name
    end

    def get_topology
      @topology
    end

    def get_topology_id
      @topology.get_topology_id
    end

    def deploy
      super()
      @deployer.request_service(self)
    end

    def undeploy
      super()
      @deployer = nil
      @service_name = nil
      @topology = nil
      @output = nil
    end

    def update_deployment
      raise "Not Implemented"
    end

    def wait(timeout)
      state = nil
      msg = nil
      thread = Thread.new do
        state, msg = @output.pop
        if state == State::DEPLOY_SUCCESS
          on_deploy_success
        else
          on_deploy_failed(msg)
        end
      end

      if thread.join(timeout)
        return true
      else
        thread.kill
        return false
      end
    end

    def on_service_finish(state, msg)
      @output << [state, msg]
    end
  end #class MySupportingServiceDeployer


  class MySupportingServicesDeployer < BaseDeployer
    def initialize(name, topology_id)
      my_id = [self.class.get_id_prefix, "topology", topology_id, "services", name].join("_")
      super(my_id, topology_id)

      @name = name
      @topology_id = topology_id
    end

    def get_id
      deployer_id
    end

    def deploy
      super()
    end

    def update_deployment
      raise "Not Implemented"
    end

    def undeploy
      super()
    end

    def get_services
      @children
    end
  end #class MySupportingServicesDeployer


  def initialize(topology_id)
    my_id = [self.class.get_id_prefix, "main", topology_id].join("_")
    super(my_id, topology_id)
  end

  def get_id
    deployer_id
  end

  def prepare_deploy(topology_xml, supporting_services, resources)
    lock_topology do
      self.reset
      self.deploy_state = State::DEPLOYING

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology, :supporting_services => supporting_services)

      @my_services.prepare_deploy unless @my_services.empty?
      @topology_deployer.prepare_deploy(topology, resources)

      self.save
    end
  end

  def deploy
    # start a new thread to do the deployment
    @worker_thread = Thread.new do
      begin
        # Check if the topology is deployable
        if @topology_deployer.deployable?
          err_msg = "The topology cannot be deployed. Make sure nodes does not have circular dependencies"
          raise DeploymentError.new(:message => err_msg)
        end

        # Let certificate authoritive node to generate keys/certs for setting up openvpn
        prepare_openvpn_credential unless @my_openvpn_service.empty?

        # This will do the deployment
        super()

        # wait for deployment finish and do error checking
        unless wait
          kill(:kill_worker => false)
          raise "Deployment timeout"
        end

        raise get_children_error if get_children_state == State::DEPLOY_FAIL
        on_deploy_success
      rescue Exception => ex
        on_deploy_failed(ex.message)
        #debug
        puts ex.message
        puts ex.backtrace[0..10].join("\n")
      end
    end
  end

  def prepare_scale(topology_xml, supporting_services, resources, nodes, diff)
    lock_topology do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology, :supporting_services => supporting_services)

      prepare_update_deployment
      @topology_deployer.prepare_scale(topology, resources, nodes, diff)

      self.save
    end
  end

  def scale
    # start a new thread to do the deployment
    @worker_thread.kill if @worker_thread
    @worker_thread = Thread.new do
      begin
        @topology_deployer.scale
        unless wait
          kill(:kill_worker => false)
          raise "Deployment timeout"
        end
        raise get_children_error if get_children_state == State::DEPLOY_FAIL
        on_update_success
      rescue Exception => ex
        on_update_failed(ex.message)
        #debug
        puts ex.message
        puts ex.backtrace[0..10].join("\n")
      end
    end
  end

  def prepare_repair(topology_xml, supporting_services, resources)
    lock_topology do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology, :supporting_services => supporting_services)

      prepare_update_deployment
      @topology_deployer.prepare_repair(topology, resources)

      self.save
    end
  end

  def repair
    @worker_thread.kill if @worker_thread
    @worker_thread = Thread.new do
      begin
        @topology_deployer.repair
        unless wait
          kill(:kill_worker => false)
          raise "Deployment timeout"
        end
        raise get_children_error if get_children_state == State::DEPLOY_FAIL
        on_update_success
      rescue Exception => ex
        on_update_failed(ex.message)
        #debug
        puts ex.message
        puts ex.backtrace[0..10].join("\n")
      end
    end
  end

  def undeploy(topology_xml, supporting_services, resources)
    lock_topology do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology, :supporting_services => supporting_services)

      @my_openvpn_service.undeploy unless @my_openvpn_service.empty?
      @my_openvpn_service = nil

      @my_services.undeploy unless @my_services.empty?
      @my_services = nil

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

  def migrate(topology_xml, supporting_services, resources, node_to_migrate, source, destination)
    lock_topology(:read_only => true) do
      self.reload

      topology = TopologyWrapper.new(topology_xml)
      initialize_deployers(topology, :supporting_services => supporting_services)

      domain = "#{node_to_migrate}_1"
      source_deployer = @topology_deployer.get_node_deployer(source, topology, resources)
      dest_deployer = @topology_deployer.get_node_deployer(destination, topology, resources)
      @migrations_deployer.schedule_migration(domain, source_deployer, dest_deployer)

      prepare_update_deployment
      self.save
    end
  end

  def on_migration_finish
    @topology_deployer.reload_update_state
    @topology_deployer.reload_update_error
    self.reload_update_state
    self.reload_update_error
  end

  def get_state
    lock_topology(:read_only => true) do
      self.reload unless self.primary_deployer?
      self.get_update_state == State::UNDEPLOY ? self.get_deploy_state : self.get_update_state
    end
  end


  protected

  def reload
    super()
    ChefNodesManager.instance.reload
    ChefClientsManager.instance.reload
    DatabagsManager.instance.reload
  end

  def prepare_openvpn_credential
    @my_openvpn_service.prepare_deploy
    @my_openvpn_service.deploy

    timeout = 120
    unless @my_openvpn_service.wait(timeout)
      raise "Timeout for acquiring openvpn service" 
    end

    success = @my_openvpn_service.get_deploy_state == State::DEPLOY_SUCCESS
    raise @my_openvpn_service.get_err_msg unless success

    @topology_deployer.load_certificates(@my_openvpn_service.get_services.first)
  end

  def initialize_deployers(topology, options={})
    services_deployers = options[:supporting_services]

    if @topology_deployer.nil?
      @topology_deployer = TopologyDeployer.new(topology.get_topology_id)
      self << @topology_deployer
    end

    if @migrations_deployer.nil?
      @migrations_deployer = MigrationsDeployer.new(topology.get_topology_id, self)
    end

    #TODO update @my_openvpn_service if it exists
    if @my_openvpn_service.nil?
      services_to_acquire = ["openvpn"]
      @my_openvpn_service = create_my_services_deployer("openvpn", services_deployers, services_to_acquire, topology)
    end

    #TODO update @my_services if it exists
    if @my_services.nil?
      services_to_acquire = ["host_protection", "dns"]
      @my_services = create_my_services_deployer("my_services", services_deployers, services_to_acquire, topology)
      self << @my_services unless @my_services.empty?
    end
  end

  def create_my_services_deployer(name, services_deployers, services_to_acquire, topology)
    topology_id = topology.get_topology_id
    my_services = MySupportingServicesDeployer.new(name, topology_id)

    services = Array.new
    services << "host_protection" if services_to_acquire.include?("host_protection") && topology.get_hids_clients.size > 0
    services << "dns"             if services_to_acquire.include?("dns") && topology.get_dns_clients.size > 0
    services << "openvpn"         if services_to_acquire.include?("openvpn") && topology.get_openvpn_clients.size > 0

    services.map do |service|
      MySupportingServiceDeployer.new(services_deployers[service], topology)
    end
  end

end