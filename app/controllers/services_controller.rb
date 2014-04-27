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
##~ @service = source2swagger.namespace("service")
##~ @service.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @service.resourcePath = "/topologies/{topology_id}/nodes/{node_id}/services"
##~ @service.swaggerVersion = "1.1"
##~ @service.apiVersion = "0.2"
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
## * define a table of supported service(This is a hack but I can't find other feasible way to do it)
##
##~ @services = {}
##~ @services["web_server"] = "Install an Tomcat6 application server"
##~ @services["database_server"] = "Install an MySQL database server"
##~ @services["web_balancer"] = "Install Apache and enable its load balancing modules"
##~ @services["server_installation"] = "Install server components of this application, which is actually a Chef server"
##~ @services["client_installation"] = "Install client coponents of this application, an installed server is required"
##~ @services["standalone_installation"] = "Install this application without a server"
##~ @services["xcamp_monitoring_agent"] = "Install an Ganglia monitoring daemon(gmond), which will collect and share various performance metric of this server"
##~ @services["xcamp_monitoring_server"] = "Install an Ganglia meta deamon(gmetad) and Ganglia web frontend, which present the collected performance metric to users"
##~ @services["xcamp_management_logic"] = "Deploy a management logic, which is a web application"
##~ @services_desc = "<h4>Available services</h4><table><thead><tr><th>attribut key</th><th>description</th></tr></thead>" + @services.sort.map{|key, value| "<tr><td>#{key}</td><td>#{value}</td></tr>"}.join + "</table>"
##
## * Model Service
##
##~ model = @service.models.Service
##~ model.id = "Service"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the service"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the service"
##~ field.allowableValues = {:valueType => "LIST", :values => @services.keys}
##
##~ field = fields.pattern
##~ field.set :type => "string", :description => "The pattern of the service"
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the service"
##
## * Model Services
##
##~ model = @service.models.Services
##~ model.id = "Services"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the services", :items => {:$ref => "Service"}
##
class ServicesController < RestfulController

  include RestfulHelper
  include ServicesHelper


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{template_id}/services"
  ##~ desc = "Show a list of service definitions"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getServicesInTemplate", :deprecated => false, :summary => api.description, :responseClass => "Services"
  ##~ notes = "Show a list of service definitions. In implementation point of view, each service match a set of scripts that will run on deployed instance."
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getServicesInNode", :deprecated => false, :summary => api.description, :responseClass => "Services"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the services(s)"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getServicesInNode", :deprecated => false, :summary => api.description, :responseClass => "Services"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service(s) belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def index
    @topology, @container, @node, @template, @services = get_list_resources params[:topology_id], params[:container_id], params[:node_id], params[:template_id]
    @pattern = get_pattern(@services)
    render :formats => "json"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{template_id}/services"
  ##~ desc = "Create a service node definition"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "createServiceInTemplate", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ notes = "Users can create a service by providing an XML document or just providing the name. The services available so far is list below" + @services_desc
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that the created service belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
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
  ##~ api.path = "/topologies/{topology_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "createServiceInNode", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the created service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "createServiceInNode", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
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

    @pattern = get_pattern(@service)
    render :action => "show", :formats => "json"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{template_id}/services/{id}"
  ##~ desc = "Show a list of service definitions"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getServiceInTemplateById", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ notes = "Show a list of service definitions. In implementation point of view, each service match a set of scripts that will run on deployed instance."
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the service"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getServiceInNodeById", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the created service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getServiceInNodeById", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service(s) belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def show
    @topology, @container, @node, @template, @service = get_resource params[:topology_id], params[:container_id], params[:node_id], params[:template_id], params[:id]
    @pattern = get_pattern(@service)
    render :formats => "json"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{template_id}/services/{id}"
  ##~ desc = "Delete the service definition"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteServiceInTemplateById", :deprecated => false, :summary => api.description, :responseClass => "Services"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the service"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteServiceInNodeById", :deprecated => false, :summary => api.description, :responseClass => "Services"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteServiceInNodeById", :deprecated => false, :summary => api.description, :responseClass => "Services"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def destroy
    @topology, @container, @node, @template, @services = get_list_resources params[:topology_id], params[:container_id], params[:node_id], params[:template_id]
    destroy_resource_by_id! @services, params[:id]

    @pattern = get_pattern(@services)
    render :action => "index", :formats => "json"
  end

  module ServiceOp
    RENAME = "rename"
    REDEFINE = "redefine"
  end


  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{template_id}/services/{id}"
  ##~ desc = "Modify the service definition"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyServiceInTemplateById", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ notes = "User can 'rename' or 'redefine' the service. If redefine, user needs to provide a new XML document as service definition." + @services_desc
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that service(s) belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "template_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of template that contains the service(s)"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
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
  ##~ api.path = "/topologies/{topology_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyServiceInNodeById", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "node_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node that contains the service"
  ##~ params[1] = param
  ##
  ##~ params.each{|p| op.parameters.add p}

  ####
  ##~ api = @service.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{node_id}/services/{id}"
  ##~ api.description = desc
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyServiceInNodeById", :deprecated => false, :summary => api.description, :responseClass => "Service"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that the service belong to"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def update
    operation = params[:operation]
    if operation.nil?
      err_msg = "Parameter 'operation' is missing."
      fail ParametersValidationError, err_msg
    end

    @topology, @container, @node, @template, @service = get_resource params[:topology_id], params[:container_id], params[:node_id], params[:template_id], params[:id]

    case operation
    when ServiceOp::RENAME
      @service.rename(params[:name])
    when ServiceOp::REDEFINE
      fail ParametersValidationError, "parameter 'definition' is missing." unless params[:definition]
      @service.redefine parse_xml(params[:definition])
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(ServiceOp).join(',')}."
      fail ParametersValidationError, err_msg
    end

    @pattern = get_pattern(@service)
    render :formats => "json", :action => "show"
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
  rescue ActiveRecord::RecordInvalid => e
    fail PatternValidationError, e.message, e.backtrace
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

  def get_model_name(options={})
    options[:plural] ? "services" : "service"
  end

end