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
require "singleton"
require "thread"

class ConcurrentHash

  def initialize
    @reader, @writer = {}, {}
    @lock = Mutex.new
  end

  def [](key)
    @reader[key]
  end

  def []=(key, value)
    @lock.synchronize do
      @writer[key] = value
      @reader, @writer = @writer, @reader
      @writer[key] = value
    end
  end

  def delete(key)
    @lock.synchronize do
      @writer.delete(key)
      @reader, @writer = @writer, @reader
      @writer.delete(key)
    end
  end

  def each(&block)
    @lock.synchronize do
      @reader.each(&block)
    end
  end

end


class DeployersManager

  include Singleton

  @@deployers = ConcurrentHash.new
  @@active_deployers = ConcurrentHash.new
  @@timeout = Rails.configuration.chef_max_deploy_time

  def initialize
    Thread.new do
      while true
        kill_timeout_deployers
        sleep 60
      end
    end
  end

  def get_deployer(key)
    @@deployers[key]
  end

  def add_deployer(key, deployer)
    @@deployers[key] = deployer
  end

  def delete_deployer(key)
    @@deployers.delete(key)
  end

  def add_active_deployer(key, deployer)
    deployer.instance_eval do
      def start_time
        @start_time
      end

      def start_time=(time)
        @start_time = time
      end
    end

    deployer.start_time = Time.now
    @@active_deployers[key] = deployer
  end

  def delete_active_deployer(key)
    @@active_deployers.delete(key)
  end

  protected

  def kill_timeout_deployers
    killed_deployers = Array.new
    @@active_deployers.each do |deployer_id, deployer|
      next if Time.now - deployer.start_time < @@timeout
      deployer.kill
      killed_deployers << deployer
    end

    killed_deployers.each{ |deployer| delete_active_deployer(deployer) }
  rescue Exception => ex
    #debug
    puts ex.message
    puts ex.backtrace[0..10].join("\n")
  end

end