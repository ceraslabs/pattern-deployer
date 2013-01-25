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
##~ @topology.basePath = "<%= request.protocol + request.host_with_port %>"
##~ @topology.swagrVersion = "0.2"
##~ @topology.apiVersion = "1.1"
class TopologiesController < RestfulController

  include RestfulHelper
  include TopologiesHelper

  before_filter :on_initialize
  
  ####
  ##~ api = @topology.apis.add
  ##~ api.path = "/api/topologies"
  ##~ api.description = "Get a list of topologies"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "get_list_of_topologies", :deprecated => false
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err if err[:code] != 400}
  ##
  def index
    @topologies = get_resources_readable_by_me(Topology.all)
    render :formats => "xml"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/api/topologies"
  ##~ api.description = "Create a new topologies definition"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "POST", :nickname => "create_topology", :deprecated => false
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

    render :action => "show", :formats => "xml"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/api/topologies/{id}"
  ##~ api.description = "Get the topology definition with id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "get_topology_by_id", :deprecated => false
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology"
  ##
  def show
    @topology = Topology.includes(:templates => :services, 
                                  :nodes => {:services => :nodes},
                                  :containers => {:nodes => {:services => :nodes}}
                                 ).find(params[:id])
    render :formats => "xml"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/api/topologies/{id}"
  ##~ api.description = "Delete the topology definition with id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "DELETE", :nickname => "delete_topology_by_id", :deprecated => false
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology"
  ##
  def destroy
    Topology.find(params[:id]).destroy

    @topologies = get_resources_readable_by_me(Topology.all)
    render :action => "index", :formats => "xml"
  end

  module TopologyOp
    RENAME = "rename"
    UPDATE_DESC = "update_description"
    DEPLOY = "deploy"
    UNDEPLOY = "undeploy"
  end


  ####
  ##~ api = @topology.apis.add
  ##~ api.set :path => "/api/topologies/{id}"
  ##~ api.description = "Modify the topology."
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "PUT", :nickname => "modify_topology_by_id", :deprecated => false
  ##~ op.summary = api.description
  ##~ op.notes = "User can use this operation to deploy or undeploy the topology to cloud. Deploying a topology will launch a set of instance(s) on the cloud(s) and install the required software stack on the instance(s). Undeploying a topology will shutdown the deployed instance(s) on the cloud(s) and cleanup the corresponse resource"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The operation which the topology is going to be executed with. 'deploy' is to deploy the topology to cloud. 'undeploy' is to undeploy the already deployed topology."
  ##~ param.allowableValues = {:valueType => "LIST", :values => ["rename", "update_description", "deploy", "undeploy"]}
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
    when TopologyOp::DEPLOY, TopologyOp::UNDEPLOY
      resources = get_resources
      services = SupportingService.get_all_services
      self.formats = [:xml]
      topology_xml = render_to_string(:partial => "topology", :locals => {:topology => @topology})

      if operation == TopologyOp::DEPLOY
        @topology.deploy(topology_xml, services, resources)
      elsif operation == TopologyOp::UNDEPLOY
        @topology.undeploy(topology_xml, services, resources)
      end
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(TopologyOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    render :action => "show", :formats => "xml"
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


  @@initialized = false

  def on_initialize
    return if @@initialized

    Topology.all.each do |topology|
      # if there is unexpected termination on previous deployment, reset the state to undeploy
      if topology.state == State::DEPLOYING
        topology.state = State::UNDEPLOY
        topology.save
      end
    end

    @@initialized = true
  end
end