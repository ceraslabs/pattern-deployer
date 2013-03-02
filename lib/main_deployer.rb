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


class MainDeployer < BaseDeployer

  # This class is an abstraction of mapping between topology and supporting service
  # This mapping is many-to-many mapping, e.g. each topology can require any number of supporting service while every supporting service can be required by any number of topologies
  # If the deployment of a topology needs supporting service, it will consume supporting service through this class
  class MySupportingServiceDeployer < BaseDeployer
    def initialize(service_deployer, topology)
      @deployer = service_deployer
      @service_name = service_deployer.get_service_name
      @topology = topology
      super()
      @output = Queue.new
    end

    def get_id
      self.class.get_id(get_topology_id, @service_name)
    end

    def self.get_id(topology_id, service_name)
      prefix = super()
      [prefix, "topology", topology_id, "service", service_name].join("_")
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

    # TODO maybe move outside
    #def get_openvpn_pairs
    #  pairs = Array.new
    #  @topology.get_openvpn_client_server_pairs.each do |ref|
    #    pair = Hash.new
    #    pair["client"] = ref["from"]
    #    pair["server"] = ref["to"]
    #    pairs << pair
    #  end

    #  pairs
    #end
  end


  class MySupportingServicesDeployer < BaseDeployer
    def initialize(name, topology_id)
      @name = name
      @topology_id = topology_id
      super()
    end

    def get_id
      self.class.get_id(@topology_id, @name)
    end

    def self.get_id(topology_id, deployer_name)
      prefix = super()
      [prefix, "topology", topology_id, "services", deployer_name].join("_")
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
  end

  def initialize(id)
    @id = id
    DatabagsManager.instance.reload
    super()
  end

  def get_id
    self.class.get_id(@id)
  end

  def self.get_id(id)
    prefix = super()
    [prefix, "main", id].join("_")
  end

  def prepare_deploy(topology_xml, supporting_services, resources)
    initialize_or_update_deployers(topology_xml,
                        :supporting_services => supporting_services,
                        :resources => resources)
    generic_prepare

    super()
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
        raise "Deployment timeout" unless wait
        raise get_err_msg if get_state == State::DEPLOY_FAIL
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
    initialize_or_update_deployers(topology_xml,
                        :supporting_services => supporting_services,
                        :resources => resources)
    generic_prepare
    prepare_update_deployment

    @topology_deployer.prepare_scale(nodes, diff)
  end

  def scale
    # start a new thread to do the deployment
    @worker_thread = Thread.new do
      begin
        @topology_deployer.scale
        raise "Deployment timeout" unless wait
        raise get_update_error if get_update_state == State::DEPLOY_FAIL
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
    initialize_or_update_deployers(topology_xml,
                        :supporting_services => supporting_services,
                        :resources => resources)
    generic_prepare

    @my_openvpn_service.undeploy unless @my_openvpn_service.empty?
    @my_openvpn_service = nil

    super()
  end

  def get_nodes_deployers(topology_xml)
    initialize_or_update_deployers(topology_xml)
    raise "Unexpected missing of topology deployer" unless @topology_deployer
    return @topology_deployer.get_children
  end


  protected

  def generic_prepare
    ChefNodesManager.instance.reload
    ChefClientsManager.instance.reload
  end

  def prepare_openvpn_credential
    @my_openvpn_service.prepare_deploy
    @my_openvpn_service.deploy

    timeout = 120
    unless @my_openvpn_service.wait(timeout)
      raise "Timeout for acquiring openvpn service" 
    end

    success = @my_openvpn_service.get_state == State::DEPLOY_SUCCESS
    raise @my_openvpn_service.get_err_msg unless success

    @topology_deployer.load_certificates(@my_openvpn_service.get_services.first)
  end

  def initialize_or_update_deployers(topology_xml, options={})
    topology = TopologyWrapper.new(topology_xml, Rails.application.config.schema_file)
    resources = options[:resources]
    services_deployers = options[:supporting_services]

    if @topology_deployer.nil?
      @topology_deployer = TopologyDeployer.new(topology, resources)
      self << @topology_deployer
    else
      @topology_deployer.set_topology(topology)
      @topology_deployer.set_resources(resources) if resources
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