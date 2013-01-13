##~ @service = source2swagger.namespace("service")
##~ @service.basePath = "localhost"
##~ @service.swagrVersion = "0.2"
##~ @service.apiVersion = "1.1"
##
## * define a table of supported service(This is a hack but I can't find other feasible way to do it)
##
##~ @services = {}
##~ @services["web_server"] = "Install an Tomcat6 application server"
##~ @services["database_server"] = "Install an MySQL database server"
##~ @services["web_balancer"] = "Install Apache and enable its load balancing modules"
##~ @services["snort_prepost"] = "Config server to connect to snort node"
##~ @services["snort"] = "Config server as snort node for network instrusion prevention"
##~ @services["server_installation"] = "Install server components of this application, which is actually a Chef server"
##~ @services["client_installation"] = "Install client coponents of this application, an installed server is required"
##~ @services["standalone_installation"] = "Install this application without a server"
##~ @services["virsh"] = "Install an virtual machine, which allow nested instance on top of existing instance"
##~ @services["openvpn_server"] = "Config server as an openvpn server(Prerequisites: supporting services 'openvpn' must be enabled)"
##~ @services["openvpn_client"] = "Config server as an openvpn client(Prerequisites: supporting services 'openvpn' must be enabled)"
##~ @services["dns_client"] = "Config server as members of load balancing dns. The dns will despatch requests to its members for load balacing purpose. (Prerequisites: supporting services 'dns' must be enabled)"
##~ @services["ossec_client"] = "Config server to use the services from ossec, which is an host-base protection system. (Prerequisites: supporting services 'host_protection' must be enabled)"
##~ @services_desc = "<h4>Available services</h4><table><thead><tr><th>attribut key</th><th>description</th></tr></thead>" + @services.map{|key, value| "<tr><td>#{key}</td><td>#{value}</td></tr>"}.join + "</table>"
class ServicesController < RestfulController

  include RestfulHelper
  include ServicesHelper


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{template_id}/services"
  ##~ desc = "Show a list of service definitions"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_list_of_services", :deprecated => false, :summary => api.description
  ##~ notes = "Show a list of service definitions. In implementation point of view, each service match a set of scripts that will run on deployed instance."
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_list_of_services", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the services(s)"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_list_of_services", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service(s) belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def index
    @topology, @container, @node, @template, @services = get_list_resources params[:topology_id], params[:container_id], params[:node_id], params[:template_id]
    render :formats => "xml"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{template_id}/services"
  ##~ desc = "Create a service node definition"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "create_service", :deprecated => false, :summary => api.description
  ##~ notes = "Users can create a service by providing an XML document or just providing the name. The services available so far is list below" + @services_desc
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that the created service belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the created service"
  ##~ params << param
  ##
  ##~ param = {:name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The new name of the service. Used in operation 'rename' operation"
  ##~ param[:allowableValues] = {:valueType => "LIST", :values => @services.keys}
  ##~ params << param
  ##
  ##~ param = {:name => "definition", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "body"}
  ##~ param[:description] = "An XML document that describe the new service. Use in 'redefine'"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "create_service", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the created service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "create_service", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service(s) belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def create
    @topology, @container, @node, @template, dump = get_list_resources params[:topology_id], params[:container_id], params[:node_id], params[:template_id]

    if definition = params[:definition]
      @service = create_resource_from_xml definition, :topology => @topology, :container => @container, :node => @node, :template => @template
    else
      if @template
        @service = @template.services.create!(:service_id => params[:name], :owner => current_user)
      else
        @service = @node.services.create!(:service_id => params[:name], :owner => current_user)
      end
    end

    render :action => "show", :formats => "xml"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{template_id}/services/{id}"
  ##~ desc = "Show a list of service definitions"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_service_by_id", :deprecated => false, :summary => api.description
  ##~ notes = "Show a list of service definitions. In implementation point of view, each service match a set of scripts that will run on deployed instance."
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the service"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_service_by_id", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the created service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_service_by_id", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service(s) belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def show
    @topology, @container, @node, @template, @service = get_resource params[:topology_id], params[:container_id], params[:node_id], params[:template_id], params[:id]
    render :formats => "xml"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{template_id}/services/{id}"
  ##~ desc = "Delete the service definition"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "delete_service_by_id", :deprecated => false, :summary => api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the service"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "delete_service_by_id", :deprecated => false, :summary => api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "delete_service_by_id", :deprecated => false, :summary => api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def destroy
    @topology, @container, @node, @template, @services = get_list_resources params[:topology_id], params[:container_id], params[:node_id], params[:template_id]
    destroy_resource_by_id! @services, params[:id]

    render :action => "index", :formats => "xml"
  end

  module ServiceOp
    RENAME = "rename"
    REDEFINE = "redefine"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{template_id}/services/{id}"
  ##~ desc = "Modify the service definition"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modify_service_by_id", :deprecated => false, :summary => api.description
  ##~ notes = "User can 'rename' or 'redefine' the service. If redefine, user needs to provide a new XML document as service definition." + @services_desc
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the service"
  ##~ params << param
  ##
  ##~ param = {:name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"}
  ##~ param[:description] = "The operatoin to execute"
  ##~ param[:allowableValues] = {:valueType => "LIST", :values => ["rename", "redefine"]}
  ##~ params << param
  ##
  ##~ param = {:name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The new name of the service. Used in operation 'rename' operation"
  ##~ param[:allowableValues] = {:valueType => "LIST", :values => @services.keys}
  ##~ params << param
  ##
  ##~ param = {:name => "definition", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "body"}
  ##~ param[:description] = "An XML document that describe the new service. Use in 'redefine'"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modify_service_by_id", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modify_service_by_id", :deprecated => false, :summary => api.description
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def update
    operation = params[:operation]
    if operation.nil?
      err_msg = "Parameter 'operation' is missing"
      raise ParametersValidationError.new(:message => err_msg)
    end

    @topology, @container, @node, @template, @service = get_resource params[:topology_id], params[:container_id], params[:node_id], params[:template_id], params[:id]

    case operation
    when ServiceOp::RENAME
      @service.rename(params[:name])
    when ServiceOp::REDEFINE
      raise ParametersValidationError.new(:message => "parameter 'definition' is missing") unless params[:definition]
      @service.redefine parse_xml(params[:definition])
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(ServiceOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    render :formats => "xml", :action => "show"
  end


  protected

  def create_resource_from_xml(xml, options={})
    service = nil
    ActiveRecord::Base.transaction do
      service_element = parse_xml(xml)
      parent = options[:template] || options[:node]
      service = create_service_scaffold(service_element, parent, current_user)
      service.update_service_attributes(service_element)
      service.update_service_connections(service_element)
    end

    service
  rescue ActiveRecord::RecordInvalid => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end

  def get_list_resources(topology_id, container_id, node_id, template_id)
    topology = Topology.find(topology_id)
    if template_id
      template = topology.templates.find(template_id)
      services = template.services
    else
      if container_id
        container = topology.containers.find(container_id) 
        node = container.nodes.find(node_id)
      else
        node = topology.nodes.find(node_id)
      end
      services = node.services
    end

    return topology, container, node, template, get_resources_readable_by_me(services)
  end

  def get_resource(topology_id, container_id, node_id, template_id, service_id)
    topology, container, node, template, services = get_list_resources topology_id, container_id, node_id, template_id
    service = find_resource_by_id! services, service_id

    return topology, container, node, template, service
  end
end
