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
require "base_deployer"
require "chef_node_deployer"


class MigrationDeployer < BaseDeployer

  def initialize(domain_deployer, source_deployer, dest_deployer, parent)
    my_id = self.class.get_migration_id(domain_deployer, source_deployer, dest_deployer)
    super(my_id, source_deployer.topology_id, parent)
  end

  def self.get_migration_id(domain_deployer, source_deployer, dest_deployer)
    topology_id = source_deployer.topology_id
    [self.get_id_prefix, "topology", topology_id, "migration", domain_deployer.get_name, source_deployer.get_name, dest_deployer.get_name].join("_")
  end

  def get_id
    deployer_id
  end

  def prepare_deploy(domain_deployer, source_deployer, dest_deployer, lb_deployer)
    migration_info = {
      "id" => self.get_id,
      "source" => source_deployer.get_id,
      "destination" => dest_deployer.get_id,
      "domain" => domain_deployer.get_name,
      "load_balancer" => lb_deployer ? lb_deployer.get_id: nil,
      "application_port" => domain_deployer["application_port"] || "80"
    }
    source_deployer["migration"] = migration_info
    dest_deployer["migration"] = migration_info
    lb_deployer["migration"] = migration_info if lb_deployer

    get_children.clear
    get_children << lb_deployer if lb_deployer
    get_children << dest_deployer
    get_children << source_deployer

    self.deploy_state = State::DEPLOYING

    save_all
  end

  def deploy
    get_children.each do |child|
      child.prepare_update_deployment
      child.save
    end

    @worker_thread = Thread.new do
      begin
        get_children.each do |child_node|
          deploy_node(child_node)
        end

        on_deploy_success
      rescue Exception => ex
        on_deploy_failed(ex.message)
        #debug
        puts ex.message
        puts ex.backtrace[0..20].join("\n")
      end
    end
  end

  def undeploy
    @worker_thread.kill if @worker_thread
    @worker_thread = nil

    begin
      get_databag.delete if get_databag
      return true, ""
    rescue Exception => ex
      puts "Unexpected exception when deleting databag"
      puts "[#{Time.now}] #{ex.class.name}: #{ex.message}"
      puts "Trace:"
      puts ex.backtrace.join("\n")
      return false, ex.message
    end
  end

  def can_start?
    return false if self.get_deploy_state != State::DEPLOYING

    get_children.all? do |child|
      child.get_update_state == State::DEPLOY_SUCCESS ||
      (child.get_update_state == State::UNDEPLOY && child.get_deploy_state == State::DEPLOY_SUCCESS)
    end
  end

  def finished?
    return true if self.get_deploy_state != State::DEPLOYING

    get_children.all? do |child|
      child.get_update_state == State::DEPLOY_SUCCESS || child.get_update_state == State::DEPLOY_FAIL
    end
  end

  def failed?
    return true if self.get_deploy_state == State::DEPLOY_FAIL

    get_children.any? do |child|
      child.get_update_state == State::DEPLOY_FAIL
    end
  end

  protected

  def deploy_node(node_deployer)
    node_deployer.update_deployment

    timeout = 600
    unless node_deployer.wait(timeout)
      kill(:kill_worker => false)
      raise "Deployment timeout"
    end

    if node_deployer.get_update_state == State::DEPLOY_FAIL
      raise node_deployer.get_update_error
    end
  end

  def save_all
    self.save
    get_children.each do |child|
      child.save
    end
  end

end #class MigrationDeployer


class MigrationsDeployer < BaseDeployer

  def initialize(topology_id, parent)
    my_id = [self.class.get_id_prefix, "topology", topology_id, "migrations"].join("_")
    super(my_id, topology_id, parent)
  end

  def schedule_migration(domain_deployer, source_deployer, dest_deployer, lb_deployer)
    migration = get_or_create_migration(domain_deployer, source_deployer, dest_deployer)
    migration.prepare_deploy(domain_deployer, source_deployer, dest_deployer, lb_deployer)
    add_migration(migration)
    if get_deploy_state != State::DEPLOYING
      set_deploy_state(State::DEPLOYING)
      deploy
    end
  end

  def deploy
    @worker_thread = Thread.new do
      while true
        state = try_deploy_and_get_state
        if state == State::DEPLOY_SUCCESS || state == State::DEPLOY_FAIL
          state == State::DEPLOY_SUCCESS ? on_deploy_success : on_deploy_failed
          @parent.on_migration_finish
          break
        end

        sleep 10
      end
    end
  end

  def add_migration(migration)
    @children << migration
  end

  def delete_migration(migration)
    @children.delete(migration)
  end

  protected

  def try_deploy_and_get_state
    finished = true
    failed = false

    get_children.each do |migration|
      migration.deploy if migration.can_start?
      if migration.finished?
        migration.undeploy
        delete_migration(migration)
        failed = true if migration.failed?
      else
        finished = false
      end
    end

    if finished
      return failed ? State::DEPLOY_FAIL : State::DEPLOY_SUCCESS
    else
      return State::DEPLOYING
    end
  rescue Exception => ex
    puts "Unexpected exception: #{ex.message}"
    puts ex.backtrace[0..10].join("\n")

    return State::DEPLOY_FAIL
  end

  def get_or_create_migration(domain_deployer, source_deployer, dest_deployer)
    migration_id = MigrationDeployer.get_migration_id(domain_deployer, source_deployer, dest_deployer)
    migration = get_children.find{ |c| c.get_id == migration_id }
    if migration.nil?
      migration = MigrationDeployer.new(domain_deployer, source_deployer, dest_deployer, self)
    end
    migration
  end

end #class MigrationsDeployer