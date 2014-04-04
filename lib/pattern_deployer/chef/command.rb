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
require 'pattern_deployer/chef/command_builder'
require 'pattern_deployer/cloud'
require 'pattern_deployer/utils'

module PatternDeployer
  module Chef
    module CommandType
      DEPLOY = 1
      UPDATE = 2
      UNDEPLOY = 3
    end

    class ChefCommand
      include CommandType
      include PatternDeployer::Cloud
      include PatternDeployer::Utils

      def initialize(command_type, node_info, options = {})
        @node_name          = node_info["node_name"]
        @node_info          = node_info
        @services           = options[:services] || Array.new
        @server_ip          = node_info["server_ip"]
        @instance_id        = options[:instance_id]
        @observers          = Array.new
        @log_file           = log_file_path(command_type)

        FileUtils.mkdir_p(Rails.configuration.chef_logs_dir)
        case command_type
        when DEPLOY
          @command  = build_create_command
        when UNDEPLOY
          @command  = build_delete_command(@instance_id)
        when UPDATE
          @command  = build_update_command
        else
          raise "unexpected command type #{command_type}"
        end
      end

      def get_command
        return @command
      end

      def build_create_command
        if ec2?
          command_builder = EC2CommandBuilder.new(@node_name, @node_info, @services)
        elsif openstack?
          command_builder = OpenStackCommandBuilder.new(@node_name, @node_info, @services)
        elsif cloud_unspecified? && @server_ip
          command_builder = BootstrapCommandBuilder.new(@node_name, @node_info, @services, @server_ip)
        else
          raise "Unexpected cloud #{@node_info["cloud"]}"
        end
        command_builder.build_create_command
      end

      def build_update_command
        command_builder = BootstrapCommandBuilder.new(@node_name, @node_info, @services, @server_ip)
        command_builder.build_create_command
      end

      def build_delete_command(instance_id)
        if ec2?
          command_builder = EC2CommandBuilder.new(@node_name, @node_info, @services)
        elsif openstack?
          command_builder = OpenStackCommandBuilder.new(@node_name, @node_info, @services)
        else
          raise "Unexpected cloud #{@node_info["cloud"]}"
        end
        command_builder.build_delete_command(instance_id)
      end

      def execute
        # avoid execute multiple knife commands at the same time
        sleep rand(10)
        # execute
        log "About to execute command: #{@command}"
        @success = execute_and_cpature_output
        log "Command finished for deploying #{@node_name}"
        @success
      end

      def stop
        return if @pid.nil?

        begin
          Process.kill("INT", @pid)
        rescue Errno::EPERM
          log "No permission to query #{@pid}!"
        rescue Errno::ESRCH
          log "#{@pid} is NOT running."
        rescue
          log "Unable to kill #{@pid} : #{$!}"
        ensure
          @pid = nil
        end
      end

      def success?
        @success == true
      end

      def failed?
        @success == false
      end

      def finished?
        !@success.nil?
      end

      def get_err_msg
        return "" unless self.finished?

        err_msg = "Failed to deploy chef node '#{@node_name}' with command: #{self.get_command}\n"
        err_msg += command_output
        err_msg
      end

      def add_observer(observer)
        @observers << observer
      end

      protected

      def execute_and_cpature_output
        IO.popen("script #{@log_file} -c '#{escaped_command}' -e") do |output|
          capture_data(output)
        end
        $?.success?
      end

      module LinePrefix
        PUBLIC_IP   = "Public IP Address"
        PRIVATE_IP  = "Private IP Address"
        FLOATING_IP = "Floating IP Address"
        INSTANCE_ID = "Instance ID"
      end

      def capture_data(output)
        output.each do |line|
          # capture public ip from stardard output
          if line.index(LinePrefix::PUBLIC_IP)
            public_ip = line.split(":")[1].strip
            notify_observers(:public_ip, public_ip)
          end

          # capture private ip from stardard output
          if line.index(LinePrefix::PRIVATE_IP)
            private_ip = line.split(":")[1].strip
            notify_observers(:private_ip, private_ip)
          end

          # capture floating ip from stardard output
          if line.index(LinePrefix::FLOATING_IP)
            floating_ip = line.split(":")[1].strip
            notify_observers(:floating_ip, floating_ip)
          end

          # capture instance id from stardard output
          if line.index(LinePrefix::INSTANCE_ID)
            instance_id = line.split(":")[1].strip
            notify_observers(:instance_id, instance_id)
          end
        end
      end

      def notify_observers(key, value)
        @observers.each do |observer|
          observer.on_data(key, value) if observer.respond_to?(:on_data)
        end
      end

      def escaped_command
        @command.gsub("'", %q{'"'"'})
      end

      def log_file_path(command_type)
        case command_type
        when DEPLOY
          [Rails.configuration.chef_logs_dir, "#{@node_name}.log"].join("/")
        when UNDEPLOY
          [Rails.configuration.chef_logs_dir, "delete_#{@node_name}.log"].join("/")
        when UPDATE
          [Rails.configuration.chef_logs_dir, "update_#{@node_name}.log"].join("/")
        end
      end

      def ec2?
        self.class.ec2?(@node_info["cloud"])
      end

      def openstack?
        self.class.openstack?(@node_info["cloud"])
      end

      def cloud_unspecified?
        self.class.cloud_unspecified?(@node_info["cloud"])
      end

      def command_output
        output = ""
        if File.exists?(@log_file)
          output += "==========>    Start output    <==========\n"
          output += `cat #{@log_file}`
          output += "==========>    End output    <==========\n"
        end
        output
      end

    end
  end
end