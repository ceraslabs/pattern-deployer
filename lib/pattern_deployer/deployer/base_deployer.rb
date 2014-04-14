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
require 'pattern_deployer/chef'
require 'pattern_deployer/deployer/attribute'
require 'pattern_deployer/deployer/state'
require 'pattern_deployer/utils'

module PatternDeployer
  module Deployer
    class BaseDeployer
      include PatternDeployer::Chef
      include PatternDeployer::Deployer::Attribute
      include PatternDeployer::Errors
      include PatternDeployer::Utils

      DEPLOY_STATE = "deploy_state"
      UPDATE_STATE = "update_state"
      DEPLOY_ERROR = "deploy_error"
      UPDATE_ERROR = "update_error"

      attr_reader :deployer_id, :topology_id, :topology_owner_id, :parent_deployer
      # these attributes persist in Chef Databag
      attribute_accessor :deploy_state, :deploy_error, :update_state, :update_error

      alias_method :databag_name, :deployer_id

      def initialize(deployer_id, parent_deployer = nil, topology_id = nil, topology_owner_id = nil)
        @deployer_id = deployer_id
        @topology_id = topology_id || parent_deployer.topology_id
        @topology_owner_id = topology_owner_id || parent_deployer.topology_owner_id
        @parent_deployer = parent_deployer if parent_deployer
        @children = Array.new
        @databag_manager = DatabagsManager.instance
      end

      def update
        data = @databag_manager.read(databag_name)
        self.attributes = data if data
      end

      def update_if_needed
        update unless topology_locked_by_me?
      end

      def reset
        attributes && attributes.clear
      end

      def get_id
        fail "Not implemented."
      end

      def self.get_id_prefix
        "PatternDeployer"
      end

      def get_children
        @children
      end

      def get_child_deployer(name)
        @children.find{ |child| child.get_name == name }
      end

      def prepare_deploy(*args)
        self.deploy_state = State::DEPLOYING

        @children.each do |child|
          child.prepare_deploy(*args)
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

      def undeploy(*args)
        @worker_thread && @worker_thread.kill
        @worker_thread = nil

        @children.each { |child| child.undeploy(*args) }
        @children.clear
        @children = nil

        @databag_manager.delete(databag_name)
        attributes.clear
        self.attributes = nil
      end

      def worker_thread_running?
        %w{ sleep run }.include?(@worker_thread.status) if @worker_thread
      end

      def kill
        @children.each{ |child| child.kill }

        if @worker_thread
          puts "About to kill deployer: #{deployer_id}"
          @worker_thread.kill
        end

        if update_state == State::DEPLOYING
          set_update_state(State::DEPLOY_FAIL)
        elsif deploy_state == State::DEPLOYING
          set_deploy_state(State::DEPLOY_FAIL)
        else
          # nothing
        end
      end

      def get_deploy_state
        get_state_by_type(DEPLOY_STATE)
      end

      def set_deploy_state(state)
        set_state_by_type(DEPLOY_STATE, state)
      end

      def get_update_state
        get_state_by_type(UPDATE_STATE)
      end

      def set_update_state(state)
        set_state_by_type(UPDATE_STATE, state)
      end

      def get_err_msg
        get_deploy_error
      end

      def set_err_msg
        set_deploy_error
      end

      def get_deploy_error
        get_error_by_type(DEPLOY_ERROR)
      end

      def set_deploy_error(msg)
        self.deploy_error = msg
        save
      end

      def get_update_error
        get_error_by_type(UPDATE_ERROR)
      end

      def set_update_error(msg)
        self.update_error = msg
        save
      end

      def ==(deployer)
        fail "Unexpected class: #{deployer.class.name}." unless deployer.kind_of?(self.class)
        get_id == deployer.get_id
      end

      def <<(child_deployer)
        @children << child_deployer
      end

      def delete_child_deployer(name)
        child = get_child_deployer(name)
        @children.delete(child)
      end

      def empty?
        @children.empty?
      end

      def key?(key)
        attributes.key?(key.to_s)
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
        fail "Invalid method call." unless topology_locked_by_me?
        @databag_manager.write(databag_name, attributes)
      end

      def undeploy?
        get_deploy_state == State::UNDEPLOY
      end

      def deploy_success?
        get_deploy_state == State::DEPLOY_SUCCESS
      end

      def deploy_failed?
        get_update_state == State::UNDEPLOY && get_deploy_state == State::DEPLOY_FAIL
      end

      def deploy_finished?
        get_deploy_state == State::DEPLOY_SUCCESS || get_deploy_state == State::DEPLOY_FAIL
      end

      def update_success?
        get_update_state == State::DEPLOY_SUCCESS
      end

      def update_failed?
        get_update_state == State::DEPLOY_FAIL
      end

      protected

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
        my_msgs = msgs.select { |msg| !msg.blank? }
        my_msgs.join("\n===============================================\n")
      end

      def self.build_err_msg(exception, deployer)
        lines = Array.new
        lines << "An error occurred when deploying '#{deployer.get_id}': #{exception.message}."
        lines << backtrace_to_s(exception.backtrace)
        remote_exception = exception.remote_exception if exception.respond_to?(:remote_exception)
        if remote_exception
          lines << "Caused by:"
          lines << remote_exception.inspect
          lines << backtrace_to_s(remote_exception.backtrace)
        end

        lines.join("\n")
      end

      def lock_topology(options={})
        fail "Unexpected missing of block." unless block_given?

        FileUtils.mkdir_p(File.dirname(lock_file))
        File.open(lock_file, "w") do |file|
          file.flock(File::LOCK_EX)
          unless options[:read_only]
            File.open(pid_file, "w"){ |file| file.write(Process.pid) }
          end

          yield
        end
      end

      def topology_locked_by_me?
        return false unless File.exists?(pid_file)

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
        if error_type == DEPLOY_ERROR
          type_of_state = DEPLOY_STATE
        elsif error_type == UPDATE_ERROR
          type_of_state = UPDATE_STATE
        else
          fail "Unexpected error_type #{error_type}."
        end

        if get_state_by_type(type_of_state) != State::DEPLOY_FAIL
          ""
        else
          attributes[error_type] || ""
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
  end
end