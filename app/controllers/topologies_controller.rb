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
require "my_errors"
require "resources_manager"

##~ @topology = source2swagger.namespace("topology")
##~ @topology.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @topology.resourcePath = "/topologies"
##~ @topology.swaggerVersion = "1.1"
##~ @topology.apiVersion = "0.2"
##~ @topology_ops = ["undeployed", "deploying", "deployed", "failed"]
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
## * Model Server
##
##~ model = @topology.models.Server
##~ model.id = "Server"
##~ fields = model.properties
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the server"
##
##~ field = fields.status
##~ field.set :type => "string", :description => "The status of the server"
##~ field.allowableValues = {:valueType => "LIST", :values => @topology_ops}
##
##~ field = fields.serverIp
##~ field.set :type => "string", :description => "The IP address of the server"
##
##~ field = fields.services
##~ field.set :type => "List", :description => "A list of services deployed/deploying to the server", :items => {:$ref => "string"}
##
## * Model Application
##
##~ model = @topology.models.Application
##~ model.id = "Application"
##~ fields = model.properties
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the application"
##
##~ field = fields.url
##~ field.set :type => "string", :description => "The url of the application"
##
##~ field = fields.inServer
##~ field.set :type => "string", :description => "The name of the server which host the application"
##
## * Model Database
##
##~ model = @topology.models.Database
##~ model.id = "Database"
##~ fields = model.properties
##
##~ field = fields.system
##~ field.set :type => "string", :description => "The database management system"
##~ field.allowableValues = {:valueType => "LIST", :values => ["mysql", "postgresql"]}
##
##~ field = fields.host
##~ field.set :type => "string", :description => "The host of the database"
##
##~ field = fields.user
##~ field.set :type => "string", :description => "The username of the database"
##
##~ field = fields.password
##~ field.set :type => "string", :description => "The password of the database's user"
##
##~ field = fields.rootPassword
##~ field.set :type => "string", :description => "The password of the root user"
##
##~ field = fields.inServer
##~ field.set :type => "string", :description => "The name of the server which host the database server"
##
## * Model Deployment
##
##~ model = @topology.models.Deployment
##~ model.id = "Deployment"
##~ fields = model.properties
##
##~ field = fields.status
##~ field.set :type => "string", :description => "The status of the deployment of topology"
##~ field.allowableValues = {:valueType => "LIST", :values => @topology_ops}
##
##~ field = fields.error
##~ field.set :type => "string", :description => "The error message of the deployment"
##
##~ field = fields.message
##~ field.set :type => "string", :description => "The message of the deployment"
##
##~ field = fields.message
##~ field.set :type => "string", :description => "The message of the deployment"
##
##~ field = fields.servers
##~ field.set :type => "List", :description => "The list of nodes that being deployed", :items => {:$ref => "Server"}
##
##~ field = fields.applications
##~ field.set :type => "List", :description => "The list of applications that being deployed", :items => {:$ref => "Application"}
##
##~ field = fields.databases
##~ field.set :type => "List", :description => "The list of databases that being deployed", :items => {:$ref => "Database"}
##
## * Model Topology
##
##~ model = @topology.models.Topology
##~ model.id = "Topology"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the topology"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the topology"
##
##~ field = fields.description
##~ field.set :type => "string", :description => "The description of the topology"
##
##~ field = fields.pattern
##~ field.set :type => "string", :description => "The pattern of the topology"
##
##~ field = fields.deployment
##~ field.set :type => "Deployment", :description => "The deployment of the topology"
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the topology"
##
##~ field = fields.templates
##~ field.set :type => "List", :description => "The list of templates of the topology", :items => {:$ref => "Template"}
##
##~ field = fields.nodes
##~ field.set :type => "List", :description => "The list of nodes that is not in any containers", :items => {:$ref => "Node"}
##
##~ field = fields.containers
##~ field.set :type => "List", :description => "The list of containers of the topology", :items => {:$ref => "Container"}
##
## * Model Topologies
##
##~ model = @topology.models.Topologies
##~ model.id = "Topologies"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the topology", :items => {:$ref => "Topology"}
##
class TopologiesController < RestfulController

  include RestfulHelper
  include TopologiesHelper
  
  ####
  ##~ api = @topology.apis.add
  ##~ api.path = "/topologies"
  ##~ api.description = "Get a list of topologies"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getTopologies", :deprecated => false, :responseClass => "Topologies"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err if err[:code] != 400}
  ##
  def index
    @topologies = get_resources_readable_by_me(Topology.all)
    @pattern = get_pattern(@topologies)
    render :formats => "json"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/topologies"
  ##~ api.description = "Create a new topologies definition"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "POST", :nickname => "createTopology", :deprecated => false, :responseClass => "Topology"
  ##~ op.summary = api.description
  ##~ op.notes = "User can upload an XML file which should contain an XML document to define the topology. Alternatively, user can send the XML definition by plain text through 'definition' parameter. Or, user can defer the topology definition by just provide the name and description."
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "file", :dataType => "file", :allowMultiple => false, :required => false, :paramType => "body"
  ##~ param.description = "This file should be an XML document to describe the topology"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "definition", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "body"
  ##~ param.description = "This file should be an XML document to describe the topology"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The name of the topology to be created."
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "description", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The description of the topology to be created"
  ##
  def create
    definition = params[:definition]
    if file_io = params[:file]
      definition = file_io.read
    end

    if definition
      @topology = create_resource_from_xml(definition)
    else
      @topology = Topology.new(:topology_id => params[:name], :description => params[:description], :state => State::UNDEPLOY, :owner => current_user)
      unless @topology.save
        raise ParametersValidationError.new(:ar_obj => @topology)
      end
    end

    @pattern = get_pattern(@topology)
    render :action => "show", :formats => "json"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/topologies/{id}"
  ##~ api.description = "Get the topology definition with id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getTopologyById", :deprecated => false, :responseClass => "Topology"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology"
  ##
  def show
    @topology = Topology.includes(:templates => :services, 
                                  :nodes => {:services => :nodes},
                                  :containers => {:nodes => {:services => :nodes}}
                                 ).find(params[:id])
    @pattern = get_pattern(@topology)
    render :formats => "json"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/topologies/{id}"
  ##~ api.description = "Delete the topology definition with id"
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteTopologyById", :deprecated => false, :responseClass => "Topologies"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology"
  ##
  def destroy
    Topology.find(params[:id]).destroy

    @topologies = get_resources_readable_by_me(Topology.all)
    @pattern = get_pattern(@topologies)
    render :action => "index", :formats => "json"
  end

  module TopologyOp
    RENAME = "rename"
    UPDATE_DESC = "update_description"
    DEPLOY = "deploy"
    UNDEPLOY = "undeploy"
    REPAIR = "repair"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/topologies/{id}"
  ##~ api.description = "Modify the topology."
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyTopologyById", :deprecated => false, :responseClass => "Topology"
  ##~ op.summary = api.description
  ##~ op.notes = "User can use this operation to deploy or undeploy the topology to cloud. Deploying a topology will launch a set of instance(s) on the cloud(s) and install the required software stack on the instance(s). Undeploying a topology will shutdown the deployed instance(s) on the cloud(s) and cleanup the corresponse resource"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The operation which the topology is going to be executed with. 'deploy' is to deploy the topology to cloud. 'undeploy' is to undeploy the already deployed topology."
  ##~ param.allowableValues = {:valueType => "LIST", :values => ["rename", "update_description", "deploy", "undeploy", "repair"]}
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The new name. Used in operation 'rename' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "description", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The new description of the topology. Used in operation 'update_description' operation"
  ##
  def update
    @topology = Topology.find(params[:id])
    
    case operation = params[:operation]
    when TopologyOp::RENAME
      raise ParametersValidationError.new(:message => "Parameter name is missing") unless params[:name]
      @topology.topology_id = params[:name]
      @topology.save!
    when TopologyOp::UPDATE_DESC
      raise ParametersValidationError.new(:message => "Parameter description is missing") unless params[:description]
      @topology.description = params[:description]
      @topology.save!
    when TopologyOp::DEPLOY, TopologyOp::UNDEPLOY, TopologyOp::REPAIR
      resources = get_resources
      services = SupportingService.get_all_services
      topology_xml = get_pattern(@topology)

      if operation == TopologyOp::DEPLOY
        @topology.deploy(topology_xml, services, resources)
      elsif operation == TopologyOp::UNDEPLOY
        @topology.undeploy(topology_xml, services, resources)
      elsif operation == TopologyOp::REPAIR
        @topology.repair(topology_xml, services, resources)
      end
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(TopologyOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    @pattern = get_pattern(@topology)
    render :action => "show", :formats => "json"
  end


  protected

  def create_resource_from_xml(xml)
    topology = nil
    ActiveRecord::Base.transaction do
      topology_element = parse_xml(xml)
      topology = create_topology_scaffold(topology_element, current_user)
      topology.update_topology_attributes(topology_element)
      topology.update_topology_connections(topology_element)
    end

    topology
  rescue ActiveRecord::RecordInvalid => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end

  def get_model_name(options={})
    options[:plural] ? "topologies" : "topology"
  end

end
