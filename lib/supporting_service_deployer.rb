require "base_deployer"
require "chef_databag"
require "chef_node"
require "chef_client"
require "my_errors"

class SupportingServiceDeployer < BaseDeployer

  def initialize(service_name)
    @service_name = service_name
    super()

    if service_deployed?
      recover
    end
  end

  def get_id
    self.class.get_id(@service_name)
  end

  def self.get_id(service_name)
    prefix = super()
    [prefix, "service", service_name].join("_")
  end

  def get_service_name
    @service_name
  end

  def prepare_deploy(resources)
    initialize_deployers(resources)

    # Load the updated list of clients and nodes
    ChefNodesManager.instance.reload
    ChefClientsManager.instance.reload

    super()
  end

  def deploy
    super()
    start_provide_service
  end

  def undeploy(resources)
    initialize_deployers(resources)

    stop_provide_service
    @queue = nil

    # load the updated list of chef clients and chef nodes into manager
    ChefNodesManager.instance.reload
    ChefClientsManager.instance.reload
    super()
  end

  def request_service(customer)
    if get_state != State::DEPLOY_SUCCESS
      err_msg = "Supporting service '#{@service_name}' is not enabled. Please enable it before deploy"
      raise DeploymentError.new(:message => err_msg)
    end

    @queue << customer
  end

  def service_deployed?
    if get_state == State::DEPLOY_SUCCESS || get_state == State::DEPLOY_FAIL
      return true
    else
      return false
    end
  end

  def include_deployer?(name)
    !!get_child_deployer(name)
  end

  def get_child_deployer(name)
    @children.find do |child|
      child.get_name == name
    end
  end


  protected

  # This method should be overwrite by sub-class
  def initialize_deployers(resources)
    raise "Not implemented"
  end

  def recover
    start_provide_service
  end

  def start_provide_service
    @worker_thread = Thread.new do
      #Thread.current[:messages] = Queue.new
      while true
        customer = @queue.pop
        #state = nil
        #err_msg = nil

        begin
          serve(customer)
          on_update_success
        rescue Exception => ex
          on_update_failed(ex)
          #err_msg = build_err_msg(ex, customer.get_topology_id)
          #debug
          puts build_err_msg(ex, customer.get_topology_id)
        ensure
          on_service_finish(customer, get_update_state, get_update_error)
        end
      end
    end
  end

  # This method can be overwrite by subclasses.
  def serve(customer, timeout = Rails.configuration.chef_max_deploy_time)
    self.set_topology_id(customer.get_topology_id)
    self.update_deployment
    self.wait(timeout)

    unless get_update_state == State::DEPLOY_SUCCESS
      msg = "Failed to acquire service #{@service_name} for topology #{customer.get_topology_id}"
      raise DeploymentError.new(:message => msg, :inner_message => get_update_error)
    end
  end

  def stop_provide_service
    @worker_thread.kill if @worker_thread
  end

  def on_service_finish(customer, state, msg)
    customer.on_service_finish(state, msg)
  end

  def set_topology_id(topology_id)
    @children.each do |child|
      child["topology_id"] = topology_id
      child.save
    end
  end

  def build_err_msg(exception, topology_id)
    msg = "Failed to acquire supporting service #{@service_name} by topology #{topology_id}:\n"
    msg += exception.message
    msg += "\nTrace:\n"
    msg += exception.backtrace.join("\n")

    msg
  end

  def create_node_deployer(node_name, image, resources, options={})
    node_info = Hash.new
    node_info["security_group"]    = "quicklanch-1"
    node_info["image"]             = image
    node_info["instance_type"]     = "t1.micro"
    node_info["cloud"]             = options[:cloud] || Rails.application.config.ec2
    node_info["availability_zone"] = "us-east-1e"
    node_info["ssh_user"]          = options[:ssh_user] || "ubuntu"
    node_info["key_pairs_id"]      = options[:key_pairs_id] if options[:key_pairs_id]
    node_info["password"]          = options[:password] if options[:password]

    services = options[:services] || Array.new
    ChefNodeDeployer.new(node_name, node_info, services, resources, self)
  end
end


class DnsDeployer < SupportingServiceDeployer
  def initialize
    service_name = "dns"
    super(service_name)
  end

  def serve(customer)
    #TODO this just need to be done once, optimize it
    dns_deployer = get_child_deployer("dns")
    dns_deployer.set_services(["update_dns"])
    dns_deployer.save

    blues_deployer = get_child_deployer("blues")
    blues_deployer.set_services(["update_blues"])
    blues_deployer["dns_node"] = dns_deployer.get_id
    blues_deployer.save

    # This will do the deployment
    super(customer)
  end


  protected

  def initialize_deployers
    self << create_dns_node_deployer(resources) unless self.include_deployer?("dns")
    self << create_blues_node_deployer(resources) unless self.include_deployer?("blues")
  end

  def create_dns_node_deployer(resources)
    node_name    = "dns"
    image        = "ami-060aa86f"
    cloud        = Rails.application.config.ec2
    key_pairs_id = resources.find_key_pair_id(cloud)

    create_node_deployer(node_name, image, resources, :cloud => cloud, :key_pairs_id => key_pairs_id)
  end

  def create_blues_node_deployer(resources)
    node_name = "blues"
    image     = "ami-c4ad00ad"
    ssh_user  = "chef"
    password  = "chef"
    services  = ["blues"]

    create_node_deployer(node_name, image, resources, :ssh_user => ssh_user, :password => password, :services => services)
  end
end


class OssecServerDeployer < SupportingServiceDeployer
  def initialize
    service_name = "host_protection"
    super(service_name)
  end


  protected

  def initialize_deployers
    self << create_hids_node_deployer(resources) unless self.include_deployer?("hids-server")
  end

  def create_hids_node_deployer(resources)
    name         = "hids-server"
    image        = "ami-cc862ba5"
    cloud        = Rails.application.config.ec2
    key_pairs_id = resources.find_key_pair_id(cloud)

    create_node_deployer(name, image, resources, :cloud => cloud, :key_pairs_id => key_pairs_id)
  end

  def serve(customer)
    deployer = @children.first
    deployer.set_services(["ossec_server"])
    deployer["hids_clients"] = customer.get_topology.get_hids_clients
    deployer.save

    super(customer)
  end
end


class CertAuthDeployer < SupportingServiceDeployer
  def initialize
    service_name = "openvpn"
    super(service_name)
  end


  protected

  def initialize_deployers
    self << create_ca_node_deployer(resources) unless self.include_deployer?("ca")
  end

  def create_ca_node_deployer(resources)
    name         = "ca"
    image        = "ami-5a5dff33"
    cloud        = Rails.application.config.ec2
    key_pairs_id = resources.find_key_pair_id(cloud)

    create_node_deployer(name, image, resources, :cloud => cloud, :key_pairs_id => key_pairs_id)
  end

  def serve(customer)
    deployer = @children.first
    deployer.set_services(["ca"])
    deployer["openvpn_client_server_pairs"] = customer.get_topology.get_openvpn_client_server_refs
    deployer.save

    timeout = 120
    super(customer, timeout)

    chef_node = deployer.get_node
    unless chef_node
      raise "Cannot get the chef node #{deployer.get_name}"
    end

    # store keys and certificates into databag
    dirty = false
    if chef_node.has_key?("server_certs")
      customer["server_certs"] = chef_node["server_certs"]
      dirty = true
    end

    if chef_node.has_key?("client_certs")
      customer["client_certs"] = chef_node["client_certs"]
      dirty = true
    end

    if dirty
      customer.save
    end
  end
end