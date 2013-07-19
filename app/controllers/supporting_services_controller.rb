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

##~ @supporting_service = source2swagger.namespace("supporting_service")
##~ @supporting_service.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @supporting_service.resourcePath = "/supporting_services"
##~ @supporting_service.swaggerVersion = "1.1"
##~ @supporting_service.apiVersion = "0.2"
##
##~ @supporting_services_descs = {}
##~ @supporting_services_descs["openvpn"] = "Provide openvpn service. Specifically, enabling this service will deploy an server which dedicates to generate keys/certificates for message encryption. User can enable this service if communications between nodes need to be secured"
##~ @supporting_services_descs["host_protection"] = "Provide host-based intrusion protection service. If enable, nodes in topology can be monitored by an ossec server to detect any potential intrusion"
##~ @supporting_services_descs["dns"] = "Provide load-balancing DNS service. If enable, nodes can subscribe itself as members of DNS. The load-balancing DNS will dispatch requests to its member(s) according to certain load-balancing scenario."
##~ @supporting_services_desc = "<h4>Supporting services</h4><table><thead><tr><th>supporting service</th><th>description</th></tr></thead>" + @supporting_services_descs.sort.map{|key, value| "<tr><td>#{key}</td><td>#{value}</td></tr>"}.join + "</table>"
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
## * Model SupportingService
##
##~ model = @supporting_service.models.SupportingService
##~ model.id = "SupportingService"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the supporting service"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the supporting service"
##~ field.allowableValues = {:valueType => "LIST", :values => @supporting_services_descs.keys}
##
##~ field = fields.available
##~ field.set :type => "boolean", :description => "The availability of the supporting service"
##
##~ field = fields.deploymentStatus
##~ field.set :type => "string", :description => "The deployment status of the supporting service"
##~ field.allowableValues = {:valueType => "LIST", :values => ["disabled", "enabling", "enabled"]}
##
##~ field = fields.deploymentError
##~ field.set :type => "string", :description => "The error message about deployment"
##
##~ field = fields.deploymentMessage
##~ field.set :type => "string", :description => "The message about deployment"
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the supporting service"
##
## * Model SupportingServices
##
##~ model = @supporting_service.models.SupportingServices
##~ model.id = "SupportingServices"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the supporting services", :items => {:$ref => "SupportingService"}
##
class SupportingServicesController < RestfulController

  ####
  ##~ api = @supporting_service.apis.add
  ##~ api.path = "/supporting_services"
  ##~ api.description = "Show a list of supporting services"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getSupportingServices", :deprecated => false, :responseClass => "SupportingServices"
  ##~ op.summary = api.description
  ##  
  ##~ errors.each{|err| op.errorResponses.add err if err[:code] != 400}
  ##
  def index
    @supporting_services = get_list_resources
    render :formats => "json"
  end


  ####
  ##~ api = @supporting_service.apis.add
  ##~ api.set :path => "/supporting_services/{id}"
  ##~ api.description = "Show the supporting service by id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getSupportingServiceById", :deprecated => false, :responseClass => "SupportingService"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of supporting service"
  ##
  def show
    @supporting_service = SupportingService.find(params[:id])
    render :formats => "json"
  end


  ####
  ##~ api = @supporting_service.apis.add
  ##~ api.set :path => "/supporting_services/{id}"
  ##~ api.description = "Enable/Disable supporting service by id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "PUT", :nickname => "modifySupportingServiceById", :deprecated => false, :responseClass => "SupportingService"
  ##~ op.summary = api.description
  ##~ op.notes = "The deployment of some services need to be supported by additional component(s). Therefore, the concept of supporting service is introduced to describe the deployment of additional component(s). E.g. In order to setup openvpn network of topology, we need to setup a certificate authority to generate keys/certificates. Only admin can enable/disable supporting services. Once a supporting service is enabled, it can be shared by all topologies." + @supporting_services_desc
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of supporting service"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "Enable/Disable the supporting service."
  ##~ param.allowableValues = {:valueType => "LIST", :values => ["enable", "disable"]}
  ##
  def update
    operation = params[:operation]
    validate_operation!(operation)

    @supporting_service = SupportingService.find(params[:id])
    resources = get_resources

    if operation == "enable"
      @supporting_service.enable(resources)
    else
      @supporting_service.disable(resources)
    end

    render :action => "show", :formats => "json"
  end


  protected

  def get_list_resources
    get_resources_readable_by_me(SupportingService.all)
  end

  def validate_operation!(operation)
    if operation.nil? || (operation != "enable" && operation != "disable")
      err_msg = "Unknown operation '#{operation}'. Only 'enable' and 'disable' are supported"
      raise ParametersValidationError.new(:message => err_msg)
    end
  end

  def initialize_db
    SupportingService.initialize_db(current_user)
  end
end