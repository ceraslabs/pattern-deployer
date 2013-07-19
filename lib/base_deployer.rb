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

  def self.deployer_attr_accessor(*my_accessors)
    my_accessors.each do |name|
      name = name.to_s

      define_method(name) do
        attributes[name]
      end

      define_method("#{name}=") do |value|
        value.nil? ? attributes.delete(name) : attributes[name] = value
      end
    end
  end


  attr_accessor :deployer_id, :attributes, :topology_id, :topology_owner_id

  deployer_attr_accessor :deploy_state, :deploy_error, :update_state, :update_error

  def initialize(deployer_id, parent_deployer = nil, topology_id = nil, topology_owner_id = nil)
    self.deployer_id = deployer_id
    self.topology_id = topology_id || parent_deployer.topology_id
    self.topology_owner_id = topology_owner_id || parent_deployer.topology_owner_id
    self.attributes = Hash.new

    @parent = parent_deployer if parent_deployer
    @children = Array.new
    @databag_manager = DatabagsManager.instance
  end

  def reload
    get_databag.reload
    self.attributes = get_databag.get_data
  end

  def reset
    self.attributes.clear
  end

  def get_id
    raise "No implementation of method get_id: this method should be overwritten by class #{self.class}"
  end

  def self.get_id_prefix
    "PatternDeployer"
  end

  def self.join(*tokens)
    tokens.join("-")
  end

  def get_owner_id
    /-user-(\d+)-topology-/.match(self.deployer_id)[1]
  end

  def get_children
    @children || Hash.new
  end

  def get_child_by_name(name)
    @children.find{ |child| child.get_name == name }
  end

  def prepare_deploy
    self.deploy_state = State::DEPLOYING

    @children.each do |child|
      child.prepare_deploy
    end
  end

  def deploy
    @children.each do |child|
      child.deploy
    end
  end

  def prepare_update_deployment
    self.update_state = State::DEPLOYING
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

    begin
      get_databag.delete if get_databag
      self.attributes.clear
    rescue Exception => ex
      puts "Unexpected exception when deleting databag"
      puts "[#{Time.now}] #{ex.class.name}: #{ex.message}"
      puts "Trace:"
      puts ex.backtrace.join("\n")
    end

    success = self.class.summarize_successes(successes)
    msg = self.class.summarize_errors(msgs)
    return success, msg
  end

  def wait(timeout = Rails.configuration.chef_max_deploy_time)
    if @worker_thread
      @worker_thread.join(timeout)
    else
      true
    end
  end

  def worker_thread_running?
    %w{ sleep run }.include?(@worker_thread.status) if @worker_thread
  end

  def kill(options={})
    @children.each{ |child| child.kill }

    kill_worker = true unless options[:keep_worker]
    if kill_worker && @worker_thread
      puts "About to kill deployer: #{deployer_id}"
      @worker_thread.kill
    end

    if self.update_state == State::DEPLOYING
      set_update_state(State::DEPLOY_FAIL)
    elsif self.deploy_state == State::DEPLOYING
      set_deploy_state(State::DEPLOY_FAIL)
    else
      # nothing
    end
  end

  def kill_children
    kill(:keep_worker => true)
  end

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
    self.deploy_error = msg
    self.save
  end

  def get_update_error
    get_error_by_type("update_error")
  end

  def set_update_error(msg)
    self.update_error = msg
    self.save
  end

  def ==(deployer)
    raise "Unexpected type of deployer: #{deployer.class.name}" unless deployer.kind_of?(self.class)
    return self.get_id == deployer.get_id
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
    attributes.has_key?(key.to_s)
  end

  def [](key)
    attributes[key.to_s]
  end

  def []=(key, value)
    attributes[key.to_s] = value if value
  end

  def delete_key(key)
    attributes.delete(key.to_s)
  end

  def save
    raise "Cannot save" unless self.primary_deployer?

    get_databag.set_data(attributes)
    get_databag.save
  end

  def self.summarize_successes(successes)
    successes.all?
  end

  def self.summarize_states(states)
    is_undeploy = true
    is_deploying = false
    is_success = true
    states.each do |state|
      is_undeploy = false if state != State::UNDEPLOY
      is_deploying = true if state == State::DEPLOYING
      is_success = false if state != State::DEPLOY_SUCCESS
    end

    return State::UNDEPLOY if is_undeploy
    return State::DEPLOYING if is_deploying
    return State::DEPLOY_SUCCESS if is_success
    return State::DEPLOY_FAIL
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

  def self.to_bool(obj)
    if obj.class == String
      "true".casecmp(obj) == 0
    else
      !!obj
    end
  end


  protected

  def lock_topology(options={})
    raise "Unexpected missing of block" unless block_given?

    FileUtils.mkdir_p(File.dirname(lock_file))
    File.open(lock_file, "w") do |file|
      file.flock(File::LOCK_EX)
      unless options[:read_only]
        File.open(pid_file, "w"){ |file| file.write(Process.pid) }
      end

      yield
    end
  end

  def primary_deployer?
    return false if not File.exists?(pid_file)
    File.open(pid_file, "r") do |file|
      file.read == Process.pid.to_s
    end
  end

  def lock_file
    Rails.root.join("tmp", "deployers", "#{topology_id}-#{topology_owner_id}.lock") if topology_id
  end

  def pid_file
    Rails.root.join("tmp", "deployers", "#{topology_id}-#{topology_owner_id}.pid") if topology_id
  end

  def get_databag
    retried = false

    begin
      @databag_manager.get_or_create_databag(deployer_id)
    rescue Net::HTTPServerException => ex
      raise ex if retried

      @databag_manager.reload
      retried = true
      retry
    end
  end

  def get_state_by_type(type_of_state)
    attributes[type_of_state] || State::UNDEPLOY
  end

  def set_state_by_type(type_of_state, state)
    if attributes[type_of_state] != state
      attributes[type_of_state] = state
      save
    end
  end

  def get_error_by_type(error_type)
    if error_type == "deploy_error"
      type_of_state = "deploy_state"
    elsif error_type == "update_error"
      type_of_state = "update_state"
    else
      raise "unexpected error_type #{error_type}"
    end

    if get_state_by_type(type_of_state) != State::DEPLOY_FAIL
      return ""
    else
      return attributes[error_type] || ""
    end
  end

  def get_children_state
    states = @children.map do |child|
      child.get_update_state == State::UNDEPLOY ? child.get_deploy_state : child.get_update_state
    end
    self.class.summarize_states(states)
  end

  def get_children_error
    errors = @children.map do |child|
      child.get_update_error == "" ? child.get_deploy_error : child.get_update_error
    end
    self.class.summarize_errors(errors)
  end

  def undeploy?
    get_deploy_state == State::UNDEPLOY
  end

  def deploy_failed?
    get_update_state == State::UNDEPLOY && get_deploy_state == State::DEPLOY_FAIL
  end

  def update_failed?
    get_update_state == State::DEPLOY_FAIL
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