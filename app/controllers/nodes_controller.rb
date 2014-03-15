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
require 'pattern_deployer'

##~ @node = source2swagger.namespace("node")
##~ @node.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @node.resourcePath = "/topologies/{topology_id}/nodes"
##~ @node.swaggerVersion = "1.1"
##~ @node.apiVersion = "0.2"
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
## * define a table of supported node attributes(This is a hack but I can't find other feasible way to do it)
##
##~ @node_attrs = {}
##~ @node_attrs["cloud"] = "The cloud this node deploy to. So far, we supported #{@clouds.join(', ')}"
##~ @node_attrs["security_groups"] = "List of security groups the node is using. Groups are comma-seperated if more than one."
##~ @node_attrs["image_id"] = "The id of the image the node will use"
##~ @node_attrs["key_pair_id"] = "The ssh key pair id which is used to create the instance"
##~ @node_attrs["ssh_user"] = "The ssh username"
##~ @node_attrs["availability_zone"] = "The Availability Zone. Used in EC2"
##~ @node_attrs["instance_type"] = "The type of the instance. For EC2, it can be 't1.micro', 'm1.small', etc. For OpenStack, it is the *ID* of instance flavor(not the name)."
##~ @node_attrs["port"] = "The ssh port. Port 22 will be used if this attribute is not set"
##~ @node_attrs["password"] = "The ssh password"
##~ @node_attrs["region"] = "The EC2/OpenStack region"
##~ @node_attrs["server_ip"] = "The IP address of the server. Use this attribute if it is an existing node"
##~ @node_attrs["use_credential"] = "Choose an uploaded credential for authentication"
##~ @node_attrs["private_network"] = "Bootstrap the node with private IP. Used in OpenStack"
##~ @node_attrs["is_external"] = "Indicate the node is external. PDS won't take any action on an external node"
##~ @node_attrs_desc = "<h4>Supported attributes</h4><table><thead><tr><th>attribut key</th><th>description</th></tr></thead>" + @node_attrs.sort.map{|key, value| "<tr><td>#{key}</td><td>#{value}</td></tr>"}.join + "</table>"
##
## * Model Node
##
##~ model = @node.models.Node
##~ model.id = "Node"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the node"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the node"
##
##~ field = fields.pattern
##~ field.set :type => "string", :description => "The pattern of the node"
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the node"
##
##~ field = fields.services
##~ field.set :type => "List", :description => "The list of services of the node", :items => {:$ref => "Service"}
##
## * Model Nodes
##
##~ model = @node.models.Nodes
##~ model.id = "Nodes"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the nodes", :items => {:$ref => "Node"}
##
class NodesController < RestfulController

  include RestfulHelper
  include NodesHelper
  include PatternDeployer::Errors


  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes"
  ##~ api.description = "Show a list of nodes definitions"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getNodes", :deprecated => false, :summary => api.description, :responseClass => "Nodes"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that node(s) belongs to"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes"
  ##~ api.description = "Show a list of nodes definitions"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getNodes", :deprecated => false, :summary => api.description, :responseClass => "Nodes"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that contains the node(s)"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def index
    @topology, @container, @nodes = get_list_resources params[:topology_id], params[:container_id]
    @pattern = get_pattern(@nodes)
    render :formats => "json"
  end


  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes"
  ##~ description = "Create a new node definition"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "createNode", :deprecated => false, :summary => api.description, :responseClass => "Node"
  ##~ notes = "User has options to create the node by name or by definition. If by name, the parameter 'name' need to be filled. If by definition, user need to send the XML document through the 'definition' parameter. Node can have a list of attributes to describe itself. The supported attributes is list below." + @node_attrs_desc
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that created node belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "definition", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "body"}
  ##~ param[:description] = "The XML document that defines the node"
  ##~ params << param
  ##
  ##~ param = {:name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The name of the node to be created. The name must be unique within topology"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "createNode", :deprecated => false, :summary => api.description, :responseClass => "Node"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that contains the created node"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def create
    @topology, @container, dump = get_list_resources params[:topology_id], params[:container_id]

    if definition = params[:definition]
      @node = create_resource_from_xml definition, :topology => @topology, :container => @container
    else
      if @container
        @node = @container.nodes.create!(:node_id => params[:name], :owner => current_user)
      else
        @node = @topology.nodes.create!(:node_id => params[:name], :owner => current_user)
      end
    end

    @pattern = get_pattern(@node)
    render :action => "show", :formats => "json"
  end


  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes/{id}"
  ##~ description = "Show a node definition by id"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getNodeById", :deprecated => false, :summary => api.description, :responseClass => "Node"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that the node belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{id}"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getNodeById", :deprecated => false, :summary => api.description, :responseClass => "Node"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that containers the node"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def show
    @topology, @container, @node = get_resource params[:topology_id], params[:container_id], params[:id]
    @pattern = get_pattern(@node)
    render :formats => "json"
  end


  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes/{id}"
  ##~ description = "Delete the node definition"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteNodeById", :deprecated => false, :summary => api.description, :responseClass => "Nodes"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that node belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{id}"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteNodeById", :deprecated => false, :summary => api.description, :responseClass => "Nodes"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that containers the node"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def destroy
    @topology, @container, @nodes = get_list_resources params[:topology_id], params[:container_id]
    destroy_resource_by_id! @nodes, params[:id]

    @pattern = get_pattern(@nodes)
    render :action => "index", :formats => "json"
  end

  module NodeOp
    RENAME = "rename"
    ADD_TEMPLATE = "add_template"
    REMOVE_TEMPLATE = "remove_template"
    SET_ATTR = "set_attribute"
    REMOVE_ATTR = "remove_attribute"
  end


  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/nodes/{id}"
  ##~ description = "Modify the definition of the node"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyNodeById", :deprecated => false, :summary => api.description, :responseClass => "Node"
  ##~ notes = "User can rename the node, add/remove template the node is using, or set/remove attributes of the node." + @node_attrs_desc
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that node belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the node"
  ##~ params << param
  ##
  ##~ param = {:name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"}
  ##~ param[:description] = "The operatoin to execute"
  ##~ param[:allowableValues] = {:valueType => "LIST", :values => ["rename", "add_template", "remove_template", "set_attribute", "remove_attribute"]}
  ##~ params << param
  ##
  ##~ param = {:name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The new name of the node. Used in operation 'rename' operation"
  ##~ params << param
  ##
  ##~ param = {:name => "template", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The name of the template to be added/removed. Use in 'add_template' or 'remove_template'"
  ##~ params << param
  ##
  ##~ param = {:name => "attribute_key", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The key of the attribute to be set/remove. Use in 'set_attribute' or 'remove_attribute'"
  ##~ param[:allowableValues] = {:valueType => "LIST", :values => @node_attrs.keys}
  ##~ params << param
  ##
  ##~ param = {:name => "attribute_value", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The value of the attribute to be set. Use in 'set_attribute'"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##

  ####
  ##~ api = @node.apis.add
  ##~ api.path = "/topologies/{topology_id}/containers/{container_id}/nodes/{id}"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyNodeById", :deprecated => false, :summary => api.description, :responseClass => "Node"
  ##~ op.notes = notes
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = {:name => "container_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the container that containers the node"
  ##~ params.insert(1, param)
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def update
    @topology, @container, @node = get_resource params[:topology_id], params[:container_id], params[:id]

    operation = params[:operation]
    if operation.nil?
      err_msg = "Parameter 'operation' is missing"
      raise ParametersValidationError.new(:message => err_msg)
    end

    case operation
    when NodeOp::RENAME
      raise ParametersValidationError.new(:message => "Parameter name is missing") unless params[:name]
      @node.rename(params[:name])
    when NodeOp::ADD_TEMPLATE
      raise ParametersValidationError.new(:message => "Parameter template is missing") unless params[:template]
      @node.add_template(params[:template])
    when NodeOp::REMOVE_TEMPLATE
      raise ParametersValidationError.new(:message => "Parameter template is missing") unless params[:template]
      @node.remove_template(params[:template])
    when NodeOp::SET_ATTR
      raise ParametersValidationError.new(:message => "Cannot find attribute's key or value to set") unless params[:attribute_key] && params[:attribute_value]
      @node.set_attr(params[:attribute_key], params[:attribute_value])
    when NodeOp::REMOVE_ATTR
      raise ParametersValidationError.new(:message => "Cannot find attribute's key to remove") unless params[:attribute_key]
      @node.remove_attr(params[:attribute_key])
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(NodeOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    @pattern = get_pattern(@node)
    render :formats => "json", :action => "show"
  end


  protected

  def create_resource_from_xml(xml, options={})
    node = nil
    ActiveRecord::Base.transaction do
      node_element = parse_xml(xml)
      parent = options[:container] || options[:topology]
      node = create_node_scaffold(node_element, parent, current_user)
      node.update_node_attributes(node_element)
      node.update_node_connections(node_element)
    end

    node
  rescue ActiveRecord::RecordInvalid => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end

  def get_list_resources(topology_id, container_id)
    topology = Topology.find(topology_id)
    container = topology.containers.find(container_id) if container_id
    if container
      nodes = container.nodes
    else
      nodes = topology.nodes
    end

    return topology, container, get_resources_readable_by_me(nodes)
  end

  def get_resource(topology_id, container_id, node_id)
    topology, container, nodes = get_list_resources topology_id, container_id
    node = find_resource_by_id! nodes, node_id

    return topology, container, node
  end

  def get_model_name(options={})
    options[:plural] ? "nodes" : "node"
  end

end