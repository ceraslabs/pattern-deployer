require "my_errors"

class RestfulController < ApplicationController
  #protect_from_forgery
  before_filter :http_authenticate
  load_and_authorize_resource

  before_filter :remove_undefined_params
  #before_filter :set_cwd

  rescue_from Exception, :with => :render_internal_error
  rescue_from ActiveRecord::RecordInvalid, :with => :render_validation_error_when_record_invalid
  rescue_from ActiveRecord::RecordNotFound, :with => :render_validation_error_when_record_not_found
  rescue_from NestedQemuError, :with => :render_app_error
  rescue_from CanCan::AccessDenied, :with => :render_access_denied

  def set_cwd
    if Rails.env != "test" && !Dir.pwd.end_with?("chef-repo")
      Dir.chdir(Dir.pwd + "/chef-repo")
    end
  end

  def http_authenticate
    request_http_basic_authentication unless user_signed_in?
  end

  def render_all
    @topologies = Topology.all
    render :formats => "xml", :template => "restful/template"
  end

  def render_404(exception = nil)
    err_msg = nil
    if exception
      err_msg = exception.message
    elsif params[:path]
      err_msg ||= "'#{request.method} #{params[:path]}' does not match to any resource"
    end
    my_exception = InvalidUrlError.new(:message => err_msg)
    render :formats => "xml", :template => "restful/app_errors", :status => my_exception.http_error_code, :locals => { :exception => my_exception }
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

  def render_notsaved_error(exception)
    render :formats => "xml",
           :template => "restful/app_errors",
           :status => 400,
           :locals => { :exception => ParametersValidationError.new(:message => exception.message, :inner_exception => exception) }
  end

  def render_access_denied(exception)
    render :formats => "xml",
           :template => "restful/app_errors",
           :status => 403,
           :locals => { :exception => AccessDeniedError.new(:message => exception.message, :inner_exception => exception) }
  end

  def convert_to_boolean(str)
    if str.class != String
      err_msg = "Cannot convert '#{str}' to boolean, since '#{str}' is not of type of String"
      raise ParametersValidationError.new(:message => err_msg)
    end

    test_str = str.downcase
    if test_str == "true"
      return true
    elsif test_str == "false"
      return false
    else
      err_msg = "Cannot convert '#{str}' to boolean, since '#{str}' is not of value 'true' or 'false'"
      raise ParametersValidationError.new(:message => err_msg)
    end
  end

  def remove_undefined_params
    params.delete_if do |key, value|
      request.POST.has_key?(key) && value == "undefined"
    end
  end
end
