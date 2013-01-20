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
      @deployer = nil
      @service_name = nil
      @topology = nil
      @output = nil
      super()
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
    initialize_deployers(topology_xml, supporting_services, resources)

    # Load the updated list of clients and nodes
    ChefNodesManager.instance.reload
    ChefClientsManager.instance.reload

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
        #debug
        puts ex.message
        puts ex.backtrace[0..10].join("\n")

        on_deploy_failed(ex.message)
      end
    end
  end

  def undeploy(topology_xml, supporting_services, resources)
    initialize_deployers_if_not_before(topology_xml, supporting_services, resources)

    # The list of clients and nodes will change during deployment so reload
    ChefNodesManager.instance.reload
    ChefClientsManager.instance.reload

    @my_openvpn_service.undeploy unless @my_openvpn_service.empty?
    @my_openvpn_service = nil

    super()
  end

  def get_nodes_deployers
    if @topology_deployer
      return @topology_deployer.get_children
    else
      return Array.new
    end
  end


  protected

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

  def initialize_deployers_if_not_before(topology_xml, services_deployers, resources)
    forced = false
    initialize_deployers(topology_xml, services_deployers, resources, forced)
  end

  def initialize_deployers(topology_xml, services_deployers, resources, forced = true)
    topology = TopologyWrapper.new(topology_xml, Rails.application.config.schema_file)
    @children.clear if forced

    if forced || @topology_deployer.nil?
      @topology_deployer = TopologyDeployer.new(topology, resources)
      self << @topology_deployer
    end

    if forced || @my_openvpn_service.nil?
      services_to_acquire = ["openvpn"]
      @my_openvpn_service = create_my_services_deployer("openvpn", services_deployers, services_to_acquire, topology)
    end

    if forced || @my_services.nil?
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

  #def get_deploy_state
  #  state = super()
  #  if state == State::UNDEPLOY && @my_openvpn_service.get_deploy_state != State::UNDEPLOY
  #    state = State::DEPLOYING
  #  end

  #  state
  #end
end