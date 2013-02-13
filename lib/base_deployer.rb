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
require "chef_databag"
require "my_errors"

module State
  UNDEPLOY = "undeployed"
  DEPLOYING = "deploying"
  DEPLOY_SUCCESS = "deployed"
  DEPLOY_FAIL = "failed"
end


class BaseDeployer

  def initialize(parent_deployer = nil)
    @parent = parent_deployer if parent_deployer
    @children = Array.new
    @databag = DatabagsManager.instance.get_or_create_databag(get_id)

    set_deploy_state(State::UNDEPLOY) if get_deploy_state == State::DEPLOYING
    set_update_state(State::UNDEPLOY) if get_update_state == State::DEPLOYING
  end

  def get_id
    raise "No implementation of method get_id: this method should be overwritten by class #{self.class}"
  end

  def self.get_id
    "NestedQEMU"
  end

  def get_children
    @children
  end

  def prepare_deploy
    @databag.reset_data
    set_state(State::DEPLOYING)

    @children.each do |child|
      child.prepare_deploy
    end
  end

  def deploy
    DeployersManager.add_deployer(get_id, self)
    @children.each do |child|
      child.deploy
    end
  end

  def prepare_update_deployment
    set_update_state(State::DEPLOYING)
  end

  def update_deployment
    @children.each do |child|
      child.update_deployment
    end
  end

  def undeploy
    successes = Array.new
    msgs = Array.new

    @children.each do |child|
      success, msg = child.undeploy
      successes << success
      msgs << msg
    end
    @children = nil

    @worker_thread.kill if @worker_thread
    @worker_thread = nil
    @databag.delete if @databag
    @databag = nil

    success = self.class.summarize_successes(successes)
    msg = self.class.summarize_errors(msgs)
    return success, msg
  end

  def wait(timeout = Rails.configuration.chef_max_deploy_time)
    @children.all? do |child|
      child.wait(timeout)
    end
  end

  def get_state
    get_deploy_state
  end

  alias :get_deployment_status :get_state

  def set_state(state)
    set_deploy_state(state)
  end

  def get_deploy_state
    get_state_by_type("deploy_state")
  end

  def set_deploy_state(state)
    set_state_by_type("deploy_state", state)
  end

  def get_update_state
    get_state_by_type("update_state")
  end

  def set_update_state(state)
    set_state_by_type("update_state", state)
  end

  def get_err_msg
    get_deploy_error
  end

  def set_err_msg
    set_deploy_error
  end

  def get_deploy_error
    get_error_by_type("deploy_error")
  end

  def set_deploy_error(msg)
    self["deploy_error"] = msg
    self.save
  end

  def get_update_error
    get_error_by_type("update_error")
  end

  def set_update_error(msg)
    self["update_error"] = msg
    self.save
  end

  def <<(child_deployer)
    @children << child_deployer
  end

  def delete_child(child)
    @children.delete(child)
  end

  def empty?
    @children.empty?
  end

  def has_key?(key)
    @databag.has_key?(key)
  end

  def [](key)
    @databag[key]
  end

  def []=(key, value)
    @databag[key] = value if value
  end

  def delete_key(key)
    @databag.delete_key(key)
  end

  def save
    @databag.save
  end

  def self.summarize_successes(successes)
    successes.all?
  end

  def self.summarize_states(states)
    is_undeploy = true
    is_success = true
    is_failed = false
    states.each do |state|
      is_undeploy = false if state != State::UNDEPLOY
      is_success = false if state != State::DEPLOY_SUCCESS
      is_failed = true if state == State::DEPLOY_FAIL
    end

    return State::UNDEPLOY if is_undeploy
    return State::DEPLOY_SUCCESS if is_success
    return State::DEPLOY_FAIL if is_failed
    return State::DEPLOYING
  end

  def self.summarize_errors(msgs)
    my_msgs = msgs.select do |msg|
      !msg.blank?
    end

    my_msgs.join("\n===============================================\n")
  end

  def self.build_err_msg(exception, deployer)
    msg = "On deploying '#{deployer.get_id}':"
    msg += "\nError: #{exception.message}"
    msg += "\nTrace: "
    msg += exception.backtrace[0..10].join("\n")
    msg += "\n............"
    if exception.class == DeploymentError
      inner_msg = exception.get_inner_message
      if inner_msg
        msg += "\nCaused by:\n"
        msg += inner_msg
      end
    end
    msg
  end


  protected

  def get_state_by_type(type_of_state)
    unless self.has_key?(type_of_state)
      return State::UNDEPLOY
    end

    if self[type_of_state] == State::DEPLOYING && !@children.empty?
      old_state = self[type_of_state]
      children_states = @children.map do |child|
        child.get_state_by_type(type_of_state)
      end
      new_state = self.class.summarize_states(children_states)
      set_state_by_type(type_of_state, new_state) if new_state != old_state
    end

    self[type_of_state]
  end

  def set_state_by_type(type_of_state, state)
    if self[type_of_state] != state
      self[type_of_state] = state
      self.save
    end
  end

  #def get_real_time_deploy_state
  #  get_real_time_state_by_type("deploy_state")
  #end

  #def get_real_time_update_state
  #  get_real_time_state_by_type("update_state")
  #end

  #def get_real_time_state_by_type(type_of_state)
  #  states = @children.map do |child|
  #    child.get_state_by_type(type_of_state)
  #  end
  #  return self.class.summarize_states(states)
  #end

  def get_error_by_type(error_type)
    if error_type == "deploy_error"
      type_of_state = "deploy_state"
    elsif error_type == "update_error"
      type_of_state = "update_state"
    else
      self["deploy_error"] = "unexpected error_type #{error_type}"
      self.save
    end

    if get_state_by_type(type_of_state) != State::DEPLOY_FAIL
      return ""
    end

    if !self.has_key?(error_type) && !@children.empty?
      errors = @children.map do |child|
        child.get_deploy_error
      end
      msg = self.class.summarize_errors(errors)
      self[error_type] = msg
      self.save
    end
    return self[error_type] || ""
  end

  def on_deploy_success
    set_deploy_state(State::DEPLOY_SUCCESS)
  end

  def on_deploy_failed(err_msg)
    set_deploy_state(State::DEPLOY_FAIL)
    set_deploy_error(err_msg)
  end

  def on_update_success
    set_update_state(State::DEPLOY_SUCCESS)
  end

  def on_update_failed(err_msg)
    set_update_state(State::DEPLOY_FAIL)
    set_update_error(err_msg)
  end
end