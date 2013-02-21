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
require "my_errors"

##~ @container = source2swagger.namespace("container")
##~ @container.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @container.resourcePath = "/topologies/{topology_id}/containers"
##~ @container.swaggerVersion = "1.1"
##~ @container.apiVersion = "0.2"
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
##~ @container_desc = "Container is used to contain node(s). Node(s) inside container can be scaled by 'num_of_copies' attribute. "
##
## * Model Container
##
##~ model = @container.models.Container
##~ model.id = "Container"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the container"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the container"
##
##~ field = fields.numOfCopies
##~ field.set :type => "int", :description => "The number of copies of nodes inside the container"
##
##~ field = fields.pattern
##~ field.set :type => "string", :description => "The pattern of the container"
##
##~ field = fields.nodes
##~ field.set :type => "List", :description => "The list of nodes of the container", :items => {:$ref => "Node"}
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the container"
##
## * Model Containers
##
##~ model = @container.models.Containers
##~ model.id = "Containers"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the containers", :items => {:$ref => "Container"}
##
class ContainersController < RestfulController

  include RestfulHelper
  include ContainersHelper


  ####
  ##~ api = @container.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers"
  ##~ api.description = "Show a list of containers definitions"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getContainers", :deprecated => false, :responseClass => "Containers"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err if err[:code] != 400}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology that container(s) belongs to"
  ##
  def index
    @topology, @containers = get_list_resources(params[:topology_id])
    @pattern = get_pattern(@containers)
    render :formats => "json"
  end


  ####
  ##~ api = @container.apis.add
  ##~ api.set :path => "/topologies/{topology_id}/containers"
  ##~ api.description = "Create a new containers definition"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "POST", :nickname => "createContainer", :deprecated => false, :responseClass => "Container"
  ##~ op.summary = api.description
  ##~ op.notes = @container_desc + " Users have 2 options to create a container: provide an XML definition or just provide the name(optionally together with the number of copies)."
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology which the list of containers belong to"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "definition", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "body"
  ##~ param.description = "This file should be an XML document to describe the container"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The name of the container to be created"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "num_of_copies", :dataType => "int", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The number of copies property. Each node inside this container will be scaled by this number of copies. Default is one"
  ##
  def create
    @topology = Topology.find(params[:topology_id])
    definition = params[:definition]
    if definition
      @container = create_resource_from_xml definition, @topology
    else
      @container = @topology.containers.create! :container_id => params[:name],
                                                :num_of_copies => params[:num_of_copies] || 1,
                                                :owner => current_user
    end

    @pattern = get_pattern(@container)
    render :action => "show", :formats => "json"
  end


  ####
  ##~ api = @container.apis.add
  ##~ api.set :path => "/topologies/{topology_id}/containers/{id}"
  ##~ api.description = "Get the container definition with id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getContainerById", :deprecated => false, :responseClass => "Container"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology which the container belongs to"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of container"
  ##
  def show
    @topology, @container = get_resource params[:topology_id], params[:id]
    @pattern = get_pattern(@container)
    render :formats => "json"
  end


  ####
  ##~ api = @container.apis.add
  ##~ api.set :path => "/topologies/{topology_id}/containers/{id}"
  ##~ api.description = "Delete the container definition"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteContainerById", :deprecated => false, :responseClass => "Containers"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology which the container belongs to"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of container"
  ##
  def destroy
    @topology, @containers = get_list_resources params[:topology_id]
    destroy_resource_by_id! @containers, params[:id]

    @pattern = get_pattern(@containers)
    render :action => "index", :formats => "json"
  end

  module ContainerOp
    RENAME = "rename"
    SCALE = "scale"
  end


  ####
  ##~ api = @container.apis.add
  ##~ api.set :path => "/topologies/{topology_id}/containers/{id}"
  ##~ api.description = "Modify the definition of the container"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyContainerById", :deprecated => false, :responseClass => "Container"
  ##~ op.summary = api.description
  ##~ op.notes = @container_desc + "User can change the name of the container or change the 'num_of_copies' attribute of the container"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of topology which the container belongs to"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of container"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The operatoin to execute"
  ##~ param.allowableValues = {:valueType => "LIST", :values => ["rename", "scale"]}
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The new name. Used with 'rename' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "num_of_copies", :dataType => "int", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The number of copies property. Each node inside this container will be scaled by this number of copies. Used with 'scale' operation"
  ##
  def update
    @topology, @container = get_resource params[:topology_id], params[:id]

    case operation = params[:operation]
    when ContainerOp::RENAME
      raise ParametersValidationError.new(:message => "Parameter name is missing") unless params[:name]
      @container.rename(params[:name])
    when ContainerOp::SCALE
      raise ParametersValidationError.new(:message => "Parameter num_of_copies is missing") unless params[:num_of_copies]

      if scale_at_runtime?
        resources = get_resources
        services = SupportingService.get_all_services
        self.formats = [:xml]
        topology_xml = render_to_string(:partial => "topologies/topology", :locals => {:topology => @topology})
        nodes = @container.nodes.map{|node| node.node_id}

        @container.num_of_copies = params[:num_of_copies]
        raise ParametersValidationError.new(:ar_obj => @container) unless @topology.unlock{@container.valid?}

        diff = @container.num_of_copies - @container.num_of_copies_was
        raise ParametersValidationError.new(:message => "num_of_copies unchanged") if diff == 0

        @topology.scale(topology_xml, services, resources, nodes, diff)
        @topology.unlock{@container.save!}
      else
        @container.num_of_copies = params[:num_of_copies]
        @container.save!
      end
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(ContainerOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    @pattern = get_pattern(@container)
    render :action => "show", :formats => "json"
  end


  protected

  def create_resource_from_xml(xml, topology)
    container = nil
    ActiveRecord::Base.transaction do
      container_element = parse_xml(xml)
      container = create_container_scaffold(container_element, topology, current_user)
      container.update_container_attributes(container_element)
      container .update_container_connections(container_element)
    end

    container
  rescue ActiveRecord::RecordInvalid => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end

  def get_list_resources(topology_id)
    topology = Topology.find(topology_id)
    containers = topology.containers
    return topology, get_resources_readable_by_me(containers)
  end

  def get_resource(topology_id, container_id)
    topology, containers = get_list_resources(topology_id)
    container = find_resource_by_id!(containers, container_id)
    return topology, container
  end

  def scale_at_runtime?
    @topology.get_state == State::DEPLOY_SUCCESS || @topology.get_state == State::DEPLOY_FAIL
  end

  def get_model_name(options={})
    options[:plural] ? "containers" : "container"
  end

end
