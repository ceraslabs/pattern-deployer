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

##~ @template = source2swagger.namespace("template")
##~ @template.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @template.resourcePath = "/topologies/{topology_id}/templates"
##~ @template.swaggerVersion = "1.1"
##~ @template.apiVersion = "0.2"
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
## * Model Template
##
##~ model = @template.models.Template
##~ model.id = "Template"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the template"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the template"
##
##~ field = fields.pattern
##~ field.set :type => "string", :description => "The pattern of the template"
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the template"
##
##~ field = fields.services
##~ field.set :type => "List", :description => "The list of services of the template", :items => {:$ref => "Service"}
##
## * Model Templates
##
##~ model = @template.models.Templates
##~ model.id = "Templates"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the templates", :items => {:$ref => "Template"}
##
class TemplatesController < RestfulController

  include RestfulHelper
  include TemplatesHelper
  include PatternDeployer::Errors


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates"
  ##~ api.description = "Show a list of templates definitions"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getTemplates", :deprecated => false, :summary => api.description, :responseClass => "Templates"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that template(s) belongs to"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def index
    @topology, @templates = get_list_resources params[:topology_id]
    @pattern = get_pattern(@templates)
    render :formats => "json"
  end

  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates"
  ##~ api.description = "Create a new template definition"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "createTemplate", :deprecated => false, :summary => api.description, :responseClass => "Template"
  ##~ @template_desc = "Template is introduced to provide a template for node definition. For example, if the several nodes share the same set of attributes/services, user can wrap those common attributes/services in a template and let the node to use that template. In addition, template can extend another template(s). If several templates share the same set of attributes/services, user can package those common definition in a base template and let the defining templates extend the base template. User can define a list of attributes of the template as they do for node" + @node_attrs_desc
  ##~ op.notes = @template_desc
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that created template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "definition", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "body"}
  ##~ param[:description] = "The XML document that defines the template"
  ##~ params << param
  ##
  ##~ param = {:name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The name of the template to be created. The name must be unique within topology"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def create
    @topology = Topology.find(params[:topology_id])

    if definition = params[:definition]
      @template = create_resource_from_xml(definition, @topology)
    else
      @template = @topology.templates.create(:template_id => params[:name], :owner => current_user)
      unless @template.save
        raise ParametersValidationError.new(:ar_obj => @template)
      end
    end

    @pattern = get_pattern(@template)
    render :action => "show", :formats => "json"
  end


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{id}"
  ##~ api.description = "Show a template definition by id"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "getTemplateById", :deprecated => false, :summary => api.description, :responseClass => "Template"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that the template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the template"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def show
    @topology, @template = get_resource params[:topology_id], params[:id]
    @pattern = get_pattern(@template)
    render :formats => "json"
  end


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{id}"
  ##~ description = "Delete the template definition"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteTemplateById", :deprecated => false, :summary => api.description, :responseClass => "Templates"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the template"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def destroy
    @topology, @templates = get_list_resources params[:topology_id]
    destroy_resource_by_id! @templates, params[:id]

    @pattern = get_pattern(@templates)
    render :action => "index", :formats => "json"
  end

  module TemplateOp
    RENAME = "rename"
    EXTEND = "extend"
    UNEXTEND = "unextend"
    SET_ATTR = "set_attribute"
    REMOVE_ATTR = "remove_attribute"
  end


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/topologies/{topology_id}/templates/{id}"
  ##~ description = "Modify the definition of the template"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyTemplateById", :deprecated => false, :summary => api.description, :responseClass => "Template"
  ##~ op.notes = "User can rename the template, add/remove base templates, or set/remove attributes of the template. " + @template_desc
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the template"
  ##~ params << param
  ##
  ##~ param = {:name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"}
  ##~ param[:description] = "The operatoin to execute"
  ##~ param[:allowableValues] = {:valueType => "LIST", :values => ["rename", "extend", "unextend", "set_attribute", "remove_attribute"]}
  ##~ params << param
  ##
  ##~ param = {:name => "name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The new name of the template. Used in operation 'rename' operation"
  ##~ params << param
  ##
  ##~ param = {:name => "base_template", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"}
  ##~ param[:description] = "The name of the base template to be added/removed. Use in 'extend' or 'unextend'"
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
  def update
    @topology, @template = get_resource params[:topology_id], params[:id]

    case operation = params[:operation]
    when TemplateOp::RENAME
      raise ParametersValidationError.new(:message => "Parameter name is missing") unless params[:name]
      @template.rename params[:name]
    when TemplateOp::EXTEND
      raise ParametersValidationError.new(:message => "Parameter template is missing") unless params[:base_template]
      @template.extend params[:base_template]
    when TemplateOp::UNEXTEND
      raise ParametersValidationError.new(:message => "Parameter template is missing") unless params[:base_template]
      @template.unextend params[:base_template]
    when TemplateOp::SET_ATTR
      raise ParametersValidationError.new(:message => "Cannot find attribute's key or value to set") unless params[:attribute_key] && params[:attribute_value]
      @template.set_attr params[:attribute_key], params[:attribute_value]
    when TemplateOp::REMOVE_ATTR
      raise ParametersValidationError.new(:message => "Cannot find attribute's key to remove") unless params[:attribute_key]
      @template.remove_attr params[:attribute_key]
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(TemplateOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    unless @template.save
      raise ParametersValidationError.new(:ar_obj => @template)
    end

    @pattern = get_pattern(@template)
    render :formats => "json", :action => "show"
  end


  protected

  def create_resource_from_xml(xml, topology)
    template = nil
    ActiveRecord::Base.transaction do
      template_element = parse_xml(xml)
      template = create_template_scaffold(template_element, topology, current_user)
      template.update_template_attributes(template_element)
      template.update_template_connections(template_element)
    end

    template
  rescue ActiveRecord::RecordInvalid => ex
    raise XmlValidationError.new(:message => ex.message, :inner_exception => ex)
  end

  def get_list_resources(topology_id)
    topology = Topology.find(topology_id)
    templates = topology.templates
    return topology, get_resources_readable_by_me(templates)
  end

  def get_resource(topology_id, template_id)
    topology, templates = get_list_resources topology_id
    template = find_resource_by_id! templates, template_id

    return topology, template
  end

  def get_model_name(options={})
    options[:plural] ? "templates" : "template"
  end

end