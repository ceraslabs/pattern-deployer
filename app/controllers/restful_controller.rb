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

class RestfulController < ApplicationController
  include PatternDeployer::Artifact
  include PatternDeployer::Errors

  #protect_from_forgery
  before_filter :token_authenticate
  before_filter :http_authenticate
  load_and_authorize_resource

  before_filter :remove_undefined_params

  rescue_from Exception, :with => :render_internal_error
  rescue_from ActiveRecord::RecordInvalid, :with => :render_bad_request_error_when_record_invalid
  rescue_from ActiveRecord::RecordNotFound, :with => :render_bad_request_error
  rescue_from PatternDeployerError, :with => :render_bad_request_error
  rescue_from ApiError, :with => :render_api_error
  rescue_from CanCan::AccessDenied, :with => :render_access_denied

  def render_404
    err_msg = "'#{request.method} #{params[:path]}' does not match to any resource." if params[:path]
    exception = InvalidUrlError.new(err_msg)
    render_api_error(exception)
  end

  def get_resources_readable_by_me(resources)
    resources.delete_if { |res| cannot? :read, res }
  end

  def get_resources_own_by_me(resources)
    resources.delete_if { |res| res.owner.id != current_user.id }
  end

  def get_artifacts(topology)
    artifacts = ArtifactsManager.new(topology, self)
    artifacts.add_artifacts(Credential.all, ArtifactType::CREDENTIAL)
    artifacts.add_artifacts(IdentityFile.all, ArtifactType::KEY_PAIR)
    artifacts.add_artifacts(WarFile.all, ArtifactType::WAR_FILE)
    artifacts.add_artifacts(SqlScriptFile.all, ArtifactType::SQL_SCRIPT)
    artifacts
  end

  def find_resource_by_id!(resources, id)
    resource = resources.find { |res| res.id == Integer(id) }
    unless resource
      err_msg = if resources.empty?
                  "Cannot find the required resource with id #{id}."
                else
                  "Cannot find the required resource '#{resources.first.class.name}' with id #{id}."
                end
      fail ParametersValidationError, err_msg
    end
    resource
  end

  def destroy_resource_by_id!(resources, id)
    resource = resources.find { |res| res.id == Integer(id) }
    unless resource
      msg = "Cannot find the required resource with id #{id}."
      fail ParametersValidationError, msg
    end
    resource.destroy
    resources.delete(resource)
  end

  def get_resource_name
    self.class.name
  end

  def get_operations(operation_module)
    ops = Array.new
    operation_module::constants.each do |const|
      ops << operation_module.const_get(const)
    end
    ops
  end

  protected

  def token_authenticate; end

  def http_authenticate
    request_http_basic_authentication unless user_signed_in?
  end

  def render_api_error(error)
    @exception = error
    render formats: "json",
           template: "restful/error",
           status: error.http_error_code
  end

  def render_internal_error(error)
    internal_error = InternalServerError.create(error)
    render_api_error(internal_error)
  end

  def render_bad_request_error_when_record_invalid(invalid_record_error)
    validation_error = ParametersValidationError.new(invalid_record_error.message)
    validation_error.set_backtrace(invalid_record_error.backtrace)
    validation_error.active_record = invalid_record_error.record
    bad_request = BadRequestError.create(validation_error)
    render_api_error(bad_request)
  end

  def render_bad_request_error(error)
    bad_request = BadRequestError.create(error)
    render_api_error(bad_request)
  end

  def render_access_denied(error)
    access_denied = AccessDeniedError.create(error)
    render_api_error(access_denied)
  end

  def remove_undefined_params
    params.delete_if do |key, value|
      request.POST.has_key?(key) && value == "undefined"
    end
  end

  def get_pattern(obj)
    if obj.class == Array
      model_name = get_model_name(:plural => true)
    else
      model_name = get_model_name
    end
    self.formats = [:xml]
    render_to_string(:partial => model_name, :locals => {model_name.to_sym => obj}).squish
  end

end