require "my_errors"

##~ @template = source2swagger.namespace("template")
##~ @template.basePath = "<%= request.protocol + request.host_with_port %>"
##~ @template.swagrVersion = "0.2"
##~ @template.apiVersion = "1.1"
class TemplatesController < RestfulController

  include RestfulHelper
  include TemplatesHelper


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates"
  ##~ api.description = "Show a list of templates definitions"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_list_of_templates", :deprecated => false, :summary => api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that template(s) belongs to"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def index
    @topology, @templates = get_list_resources params[:topology_id]
    render :formats => "xml"
  end

  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates"
  ##~ api.description = "Create a new template definition"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "create_template", :deprecated => false, :summary => api.description
  ##~ @template_desc = "Template is introduced to provide a template for node definition. For example, if the several nodes share the same set of attributes/services, user can wrap those common attributes/services in a template and let the node to use that template. In addition, template can extend another template(s). If several templates share the same set of attributes/services, user can package those common definition in a base template and let the defining templates extend the base template. User can define a list of attributes of the template as they do for node" + @node_attrs_desc
  ##~ op.notes = @template_desc
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
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

    render :action => "show", :formats => "xml"
  end


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{id}"
  ##~ api.description = "Show a template definition by id"
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "GET", :nickname => "get_template_by_id", :deprecated => false, :summary => api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that the template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the template"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def show
    @topology, @template = get_resource params[:topology_id], params[:id]
    render :formats => "xml"
  end


  ####
  ##~ api = @template.apis.add
  ##~ api.path = "/api/topologies/{topology_id}/templates/{id}"
  ##~ description = "Delete the template definition"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "DELETE", :nickname => "delete_template_by_id", :deprecated => false, :summary => api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of the template"
  ##~ params << param
  ##
  ##~ params.each{|p| op.parameters.add p}
  ##
  def destroy
    @topology, @templates = get_list_resources params[:topology_id]
    destroy_resource_by_id! @templates, params[:id]

    render :action => "show", :formats => "xml"
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
  ##~ api.path = "/api/topologies/{topology_id}/templates/{id}"
  ##~ description = "Modify the definition of the template"
  ##~ api.description = description
  ##
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "PUT", :nickname => "modify_template_by_id", :deprecated => false, :summary => api.description
  ##~ op.notes = "User can rename the template, add/remove base templates, or set/remove attributes of the template. " + @template_desc
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ params = []
  ##
  ##~ param = {:name => "topology_id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
  ##~ param[:description] = "The unique id of topology that template belongs to"
  ##~ params << param
  ##
  ##~ param = {:name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"}
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

    render :formats => "xml", :action => "show"
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
end
