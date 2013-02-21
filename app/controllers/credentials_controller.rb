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

##~ @credential = source2swagger.namespace("credential")
##~ @credential.basePath = "<%= request.protocol + request.host_with_port %>/api"
##~ @credential.resourcePath = "/credentials"
##~ @credential.swaggerVersion = "1.1"
##~ @credential.apiVersion = "0.2"
##~ @clouds = ["ec2", "openstack"]
##
##~ errors = []
##~ errors << {:reason => "user provided invalid parameter(s)", :code => 400}
##~ errors << {:reason => "user haven't logined", :code => 401}
##~ errors << {:reason => "user doesnot have permission for this operation", :code => 403}
##~ errors << {:reason => "some weird error occurs, possibly due to bug(s)", :code => 500}
##
## * Model Credential
##
##~ model = @credential.models.Credential
##~ model.id = "Credential"
##~ fields = model.properties
##
##~ field = fields.id
##~ field.set :type => "int", :description => "The id of the credential"
##
##~ field = fields.name
##~ field.set :type => "string", :description => "The name of the credential"
##
##~ field = fields.forCloud
##~ field.set :type => "string", :description => "The cloud that the credential is for"
##~ field.allowableValues = {:valueType => "LIST", :values => @clouds}
##
##~ field = fields.awsAccessKeyId
##~ field.set :type => "string", :description => "The EC2 access key id"
##
##~ field = fields.openstackUsername
##~ field.set :type => "string", :description => "The OpenStack username"
##
##~ field = fields.openstackTenant
##~ field.set :type => "string", :description => "The OpenStack tenant"
##
##~ field = fields.openstackEndpoint
##~ field.set :type => "string", :description => "The OpenStack endpoint"
##
##~ field = fields.link
##~ field.set :type => "string", :description => "The link of the credential"
##
## * Model Credentials
##
##~ model = @credential.models.Credentials
##~ model.id = "Credentials"
##~ fields = model.properties
##
##~ field = fields.all
##~ field.set :type => "List", :description => "The information of the credentials", :items => {:$ref => "Credential"}
##
class CredentialsController < RestfulController

  ####
  ##~ api = @credential.apis.add
  ##~ api.path = "/credentials"
  ##~ api.description = "Show a list of credentials"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getCredentials", :deprecated => false, :responseClass => "Credentials"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err if err[:code] != 400}
  ##
  def index
    @credentials = get_resources_readable_by_me(Credential.all)
    render :formats => "json"
  end


  ####
  ##~ api = @credential.apis.add
  ##~ api.path = "/credentials"
  ##~ api.description = "Create a new credential"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "POST", :nickname => "createCredential", :deprecated => false, :responseClass => "Credential"
  ##~ op.summary = api.description
  ##~ op.notes = "The created credential will be used to authenticate user against the cloud when deploying a topology. User need to provide a name for the created credential and indicate which cloud this credential belongs to. Depending on different cloud provider, user need to fill the corresponse parameter(s) to define the credential"
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "name", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The unique name of the credential."
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "for_cloud", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.allowableValues = {:valueType => "LIST", :values => @clouds}
  ##~ param.description = "The cloud that the created credential belongs to"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "access_key_id", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your Amazon Web Services access key ID. Required if the cloud is 'ec2'"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "secret_access_key", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your Amazon Web Services secret access key. Required if the cloud is 'ec2'"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "username", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your OpenStack username. Required if the cloud is 'openstack'"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "password", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your OpenStack password. Required if the cloud is 'openstack'"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "tenant", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your OpenStack tenant. Required if the cloud is 'openstack'"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "endpoint", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your OpenStack API endpoint. Required if the cloud is 'openstack'"
  ##
  def create
    for_cloud = params[:for_cloud]
    if for_cloud.class != String
      err_msg = "The request doesnot container parameter 'for_cloud'"
      raise ParametersValidationError.new(:message => err_msg)
    else
      for_cloud = for_cloud.downcase
    end

    if for_cloud == Rails.application.config.ec2
      @credential = Ec2Credential.new(:credential_id => params[:name], 
                                      :for_cloud => params[:for_cloud],
                                      :owner => current_user,
                                      :aws_access_key_id => params[:access_key_id],
                                      :aws_secret_access_key => params[:secret_access_key])
    elsif for_cloud == Rails.application.config.openstack
      @credential = OpenstackCredential.new(:credential_id => params[:name], 
                                            :for_cloud => params[:for_cloud],
                                            :owner => current_user,
                                            :openstack_username => params[:username],
                                            :openstack_password => params[:password],
                                            :openstack_tenant => params[:tenant],
                                            :openstack_endpoint => params[:endpoint])
    else
      err_msg = "The cloud #{cloud} is not supported. Only #{SUPPORTED_CLOUD.join(', ')} are supported"
      raise ParametersValidationError.new(:message => err_msg)
    end

    if @credential.save
      render :formats => "json", :action => "show"
    else
      raise ParametersValidationError.new(:ar_obj => @credential)
    end
  end


  ####
  ##~ api = @credential.apis.add
  ##~ api.set :path => "/credentials/{id}"
  ##~ api.description = "Get the credential definition with id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "getCredentialById", :deprecated => false, :responseClass => "Credential"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of credential"
  ##
  def show
    @credential = Credential.find(params[:id])
    render :formats => "json"
  end

  ####
  ##~ api = @credential.apis.add
  ##~ api.set :path => "/credentials/{id}"
  ##~ api.description = "Delete the credential definition by id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "DELETE", :nickname => "deleteCredentialById", :deprecated => false, :responseClass => "Credentials"
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of credential"
  ##
  def destroy
    Credential.find(params[:id]).destroy

    @credentials = get_resources_readable_by_me(Credential.all)
    render :formats => "json", :action => "index"
  end

  module CredentialOp
    RENAME = "rename"
    REDEF = "redefine"
  end

  ####
  ##~ api = @credential.apis.add
  ##~ api.set :path => "/credentials/{id}"
  ##~ api.description = "Modify the credential."
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "PUT", :nickname => "modifyCredentialById", :deprecated => false, :responseClass => "Credential"
  ##~ op.summary = api.description
  ##~ op.notes = "Two operation available: 'rename' and 'redefine'. Operation 'redefine' can be used to change the attribute/key/password of existing credential."
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "int", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of credential"
  ##  
  ##~ param = op.parameters.add
  ##~ param.set :name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The operation to execut"
  ##~ param.allowableValues = {:valueType => "LIST", :values => ["rename", "redefine"]}
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "name", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The new name of the credential. Used in 'rename' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "access_key_id", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your new Amazon Web Services access key ID. Used in 'redefine' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "secret_access_key", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your new Amazon Web Services secret access key. Used in 'redefine' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "username", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your new OpenStack username. Used in 'redefine' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "password", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your new OpenStack password. Used in 'redefine' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "tenant", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your new OpenStack tenant. Used in 'redefine' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "endpoint", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "Your new OpenStack API endpoint. Used in 'redefine' operation"
  ##
  def update
    @credential = Credential.find(params[:id])

    case operation = params[:operation]
    when CredentialOp::RENAME
      raise ParametersValidationError.new(:message => "parameter 'name' is not provided") unless params[:name]
      @credential.credential_id = params[:name]
    when CredentialOp::REDEF
      if @credential.class == Ec2Credential
        @credential.aws_access_key_id = params[:access_key_id] || @credential.aws_access_key_id
        @credential.aws_secret_access_key = params[:secret_access_key] || @credential.aws_secret_access_key
      else
        @credential.openstack_username = params[:username] || @credential.openstack_username 
        @credential.openstack_password = params[:password] || @credential.openstack_password 
        @credential.openstack_tenant = params[:tenant] || @credential.openstack_tenant 
        @credential.openstack_endpoint = params[:endpoint] || @credential.openstack_endpoint 
      end
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(CredentialOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    unless @credential.save
      raise ParametersValidationError.new(:ar_obj => @credential)
    end

    render :action => "show", :formats => "json"
  end
end