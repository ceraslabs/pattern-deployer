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

##~ @file = source2swagger.namespace("uploaded_file")
##~ @file.basePath = "<%= request.protocol + request.host_with_port %>"
##~ @file.swagrVersion = "0.2"
##~ @file.apiVersion = "1.1"
##
##~ @types_descs = {}
##~ @types_descs["identity_file"] = "Identity file contains private key that is used to ssh to the deployed instance. An identity file should match a keypair of the cloud and should have an suffix '.pem'"
##~ @types_descs["war_file"] = "Java application archive. An war file should have suffix '.war'"
##~ @types_descs["sql_script_file"] = "An sql script file which is used to setup the schema/tables of database"
##~ @file_type_desc = "<h4>File types</h4><table><thead><tr><th>type</th><th>description</th></tr></thead>" + @types_descs.map{|key, value| "<tr><td>#{key}</td><td>#{value}</td></tr>"}.join + "</table>"
class UploadedFilesController < RestfulController

  ####
  ##~ api = @file.apis.add
  ##~ api.path = "/api/uploaded_files"
  ##~ api.description = "Show a list of uploaded files"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "get_list_of_files", :deprecated => false
  ##~ op.summary = api.description
  ##  
  ##~ errors.each{|err| op.errorResponses.add err if err[:code] != 400}
  ##
  def index
    @files = get_resources_readable_by_me(UploadedFile.all)
    render :formats => "xml"
  end


  ####
  ##~ api = @file.apis.add
  ##~ api.path = "/api/uploaded_files"
  ##~ api.description = "Upload a file"
  ##~ op = api.operations.add
  ##~ op.set :httpMethod => "POST", :nickname => "create_file", :deprecated => false
  ##~ op.summary = api.description
  ##~ op.notes = "User need to provide a name for the created file. Depending on file type, user may need to fill additional parameter(s)" + @file_type_desc
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "file", :dataType => "file", :allowMultiple => false, :required => true, :paramType => "body"
  ##~ param.description = "The uploaded file"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "file_type", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.allowableValues = {:valueType => "LIST", :values => @types_descs.keys}
  ##~ param.description = "The type of the uploaded file"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "file_name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The name of the uploaded file. Use this parameter if user want a name different from the orignal file name."
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "key_pair_id", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The key pair id of the identify file"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "for_cloud", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.allowableValues = {:valueType => "LIST", :values => @clouds}
  ##~ param.description = "The cloud where this key pair belongs to"
  ##
  def create
    if file_type = params[:file_type]
      file_type = file_type.downcase
    else
      err_msg = "The request doesnot container parameter 'file_type'"
      raise ParametersValidationError.new(:message => err_msg)
    end

    if file_io = params[:file]
      default_file_name = file_io.original_filename
    else
      err_msg = "The request doesnot container parameter 'file'"
      raise ParametersValidationError.new(:message => err_msg)
    end

    if file_type == "identity_file"
      @file = IdentityFile.new(:file_name => params[:file_name] || default_file_name,
                               :key_pair_id => params[:key_pair_id],
                               :for_cloud => params[:for_cloud],
                               :owner => current_user)
    elsif file_type == "war_file"
      @file = WarFile.new(:file_name => params[:file_name] || default_file_name,
                          :owner => current_user)
    elsif file_type == "sql_script_file"
      @file = SqlScriptFile.new(:file_name => params[:file_name] || default_file_name,
                                :owner => current_user)
    else
      err_msg = "Unsupported type of file #{file_type}, only 'identity_file', 'war_file', or 'sql_script_file' is supported"
      raise ParametersValidationError.new(:message => err_msg)
    end

    @file.upload(file_io)

    if @file.save
      render :formats => "xml", :action => "show"
    else
      raise ParametersValidationError.new(:ar_obj => @file)
    end
  end


  ####
  ##~ api = @file.apis.add
  ##~ api.set :path => "/api/uploaded_files/{id}"
  ##~ api.description = "Delete the uploaded file by id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "GET", :nickname => "get_file_by_id", :deprecated => false
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of the uploaded file"
  ##
  def show
    @file = UploadedFile.find(params[:id])
    render :formats => "xml"
  end


  ####
  ##~ api = @file.apis.add
  ##~ api.set :path => "/api/uploaded_files/{id}"
  ##~ api.description = "Delete the uploaded file by id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "DELETE", :nickname => "delete_file_by_id", :deprecated => false
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of uploaded file"
  ##
  def destroy
    UploadedFile.find(params[:id]).destroy

    @files = get_resources_readable_by_me(UploadedFile.all)
    render :formats => "xml", :action => "index"
  end

  module FileOp
    RENAME = "rename"
    REUPLOAD = "reupload"
  end


  ####
  ##~ api = @file.apis.add
  ##~ api.set :path => "/api/uploaded_files/{id}"
  ##~ api.description = "Modify the uploaded file by id"
  ##~ op = api.operations.add   
  ##~ op.set :httpMethod => "PUT", :nickname => "modify_file_by_id", :deprecated => false
  ##~ op.summary = api.description
  ##
  ##~ errors.each{|err| op.errorResponses.add err}
  ##
  ##  * declaring parameters
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "id", :dataType => "integer", :allowMultiple => false, :required => true, :paramType => "path"
  ##~ param.description = "The unique id of uploaded file"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "operation", :dataType => "string", :allowMultiple => false, :required => true, :paramType => "query"
  ##~ param.description = "The operation to execute"
  ##~ param.allowableValues = {:valueType => "LIST", :values => ["rename", "reupload"]}
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "file", :dataType => "file", :allowMultiple => false, :required => false, :paramType => "body"
  ##~ param.description = "The new file. Used with 'reupload' operation"
  ##
  ##~ param = op.parameters.add
  ##~ param.set :name => "file_name", :dataType => "string", :allowMultiple => false, :required => false, :paramType => "query"
  ##~ param.description = "The new file name. Used with 'rename' operation"
  ##
  def update
    operation = params[:operation]
    if operation.nil?
      err_msg = "Parameter 'operation' is missing"
      raise ParametersValidationError.new(:message => err_msg)
    end

    @file = UploadedFile.find(params[:id])

    case operation
    when FileOp::RENAME
      raise ParametersValidationError.new(:message => "parameter 'file_name' is missing") unless params[:file_name]
      @file.rename(params[:file_name])
    when FileOp::REUPLOAD
      raise ParametersValidationError.new(:message => "parameter 'file' is missing") unless params[:file]
      @file.reupload(params[:file])
    else
      err_msg = "Invalid operation. Supported operations are #{get_operations(FileOp).join(',')}"
      raise ParametersValidationError.new(:message => err_msg)
    end

    render :formats => "xml", :action => "show"
  end
end