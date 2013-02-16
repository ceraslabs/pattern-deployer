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

class RestfulController < ApplicationController
  #protect_from_forgery
  before_filter :http_authenticate
  load_and_authorize_resource

  before_filter :remove_undefined_params

  rescue_from Exception, :with => :render_internal_error
  rescue_from ActiveRecord::RecordInvalid, :with => :render_validation_error_when_record_invalid
  rescue_from ActiveRecord::RecordNotFound, :with => :render_validation_error_when_record_not_found
  rescue_from PatternDeployerError, :with => :render_app_error
  rescue_from CanCan::AccessDenied, :with => :render_access_denied

  def http_authenticate
    request_http_basic_authentication unless user_signed_in?
  end

  def get_resources_readable_by_me(resources)
    resources.delete_if {|res| cannot? :read, res}
  end

  def get_resources_own_by_me(resources)
    resources.delete_if {|res| res.owner.id != current_user.id}
  end

  def get_resources
    resources = ResourcesManager.new
    resources.add_resources_if_not_added get_resources_own_by_me(Credential.all), Resource::CREDENTIAL, :is_mine => true
    resources.add_resources_if_not_added get_resources_readable_by_me(Credential.all), Resource::CREDENTIAL
    resources.add_resources_if_not_added get_resources_own_by_me(IdentityFile.all), Resource::KEY_PAIR, :is_mine => true
    resources.add_resources_if_not_added get_resources_readable_by_me(IdentityFile.all), Resource::KEY_PAIR
    resources.add_resources_if_not_added get_resources_own_by_me(WarFile.all), Resource::WAR_FILE, :is_mine => true
    resources.add_resources_if_not_added get_resources_readable_by_me(WarFile.all), Resource::WAR_FILE
    resources.add_resources_if_not_added get_resources_own_by_me(SqlScriptFile.all), Resource::SQL_SCRIPT, :is_mine => true
    resources.add_resources_if_not_added get_resources_readable_by_me(SqlScriptFile.all), Resource::SQL_SCRIPT
    resources
  end

  def find_resource_by_id!(resources, id)
    resource = resources.select{|res| res.id == Integer(id)}.first
    unless resource
      if resources.empty?
        err_msg = "Cannot find the required resource with id #{id}"
      else
        err_msg = "Cannot find the required resource '#{resources.first.class.name}' with id #{id}"
      end
      raise ParametersValidationError.new(:message => err_msg)
    end
    resource
  end

  def destroy_resource_by_id!(resources, id)
    resource = resources.select{|res| res.id == Integer(id)}.first
    unless resource
      raise ParametersValidationError.new(:message => "Cannot find the required resource with id #{id}")
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

  def render_app_error(exception)
    render :formats => "xml", :template => "restful/app_errors", :status => exception.http_error_code, :locals => { :exception => exception }
  end

  def render_internal_error(exception)
    render :formats => "xml", :template => "restful/internal_errors", :status => 500, :locals => { :exception => exception }
  end

  def render_validation_error_when_record_invalid(invalid_record)
    err_msg = invalid_record.record.errors.full_messages.join(";")
    render :formats => "xml",
           :template => "restful/app_errors",
           :status => 400,
           :locals => { :exception => ParametersValidationError.new(:message => err_msg, :inner_exception => invalid_record) }
  end

  def render_validation_error_when_record_not_found(exception)
    render :formats => "xml",
           :template => "restful/app_errors",
           :status => 400,
           :locals => { :exception => ParametersValidationError.new(:message => exception, :inner_exception => exception) }
  end

  def render_access_denied(exception)
    render :formats => "xml",
           :template => "restful/app_errors",
           :status => 403,
           :locals => { :exception => AccessDeniedError.new(:message => exception.message, :inner_exception => exception) }
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
    render_to_string(:partial => model_name, :locals => {model_name.to_sym => obj}).squish.gsub('"', "'")
  end

end