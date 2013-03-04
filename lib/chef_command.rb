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
module CommandType
  DEPLOY = 1
  UPDATE = 2
  UNDEPLOY = 3
end


class ChefCommand

  def initialize(type, node_info, options = {})
    @type               = type
    @node_name          = node_info["node_name"]
    @node_info          = node_info
    @services           = options[:services] || Array.new
    @server_ip          = node_info["server_ip"]
    @instance_id        = options[:instance_id]
    @observers          = Array.new
    @public_ip_prefix   = "Public IP Address"
    @private_ip_prefix  = "Private IP Address"
    @floating_ip_prefix = "Floating IP Address"
    @instance_id_prefix = "Instance ID"

    FileUtils.mkdir_p(Rails.configuration.chef_logs_dir)
    case type
    when CommandType::DEPLOY
      @command  = build_create_command
      @log_file = [Rails.configuration.chef_logs_dir, "#{@node_name}.log"].join("/")
    when CommandType::UNDEPLOY
      @command  = build_delete_command(@instance_id)
      @log_file = [Rails.configuration.chef_logs_dir, "delete_#{@node_name}.log"].join("/")
    when CommandType::UPDATE
      @command  = build_update_command
      @log_file = [Rails.configuration.chef_logs_dir, "update_#{@node_name}.log"].join("/")
    else
      raise "unexpected command type #{type}"
    end
  end

  def get_command
    return @command
  end

  def get_log_file
    return @log_file
  end

  def build_create_command
    if @node_info["cloud"].downcase == Rails.application.config.notcloud
      command_builder = BootstrapCommandBuilder.new(@node_name, @node_info, @services, @server_ip)
    elsif @node_info["cloud"].downcase == Rails.application.config.ec2
      command_builder = EC2CommandBuilder.new(@node_name, @node_info, @services)
    elsif @node_info["cloud"].downcase == Rails.application.config.openstack
      command_builder = OpenStackCommandBuilder.new(@node_name, @node_info, @services)
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
    if @node_info["cloud"].downcase == Rails.application.config.ec2
      command_builder = EC2CommandBuilder.new(@node_name, @node_info, @services)
    elsif @node_info["cloud"].downcase == Rails.application.config.openstack
      command_builder = OpenStackCommandBuilder.new(@node_name, @node_info, @services)
    else
      raise "Unexpected cloud #{@node_info["cloud"]}"
    end

    command_builder.build_delete_command(instance_id)
  end

  def execute
    #debug
    puts "[#{Time.now}] About to execute command: #{@command}"

    if @node_info.has_key?("cloud") && (@node_info["cloud"].downcase == Rails.application.config.ec2 || @node_info["cloud"].downcase == Rails.application.config.openstack)
      success = execute_and_cpature_output
    else
      success = execute_and_retry_on_fail
    end

    #debug
    puts "[#{Time.now}] Command finished for deploying #{@node_name}"

    success
  end

  def execute_and_cpature_output
    status = Open4::popen4("script #{@log_file} -c '#{@command}' -e") do |pid, stdin, stdout, stderr|
      stdin.close
      @pid = pid
      capture_data(stdout)
    end

    return status.success?
  end

  def execute_and_retry_on_fail(initial_wait = 60, timeout = 300)
    # The nested instance takes at least 1 min to boot, so sleep 1 min
    sleep initial_wait

    success = false
    start = Time.now
    now = Time.now
    until (now - start) > timeout
      success = system("script #{@log_file} -c '#{@command}' -e")

      break if success

      sleep 2
      now = Time.now
    end

    success
  end

  def stop
    return if @pid.nil?

    begin
      Process.kill("INT", @pid)
    rescue Errno::EPERM
      puts "No permission to query #{@pid}!";
    rescue Errno::ESRCH
      puts "#{@pid} is NOT running.";
    rescue
      puts "Unable to kill #{@pid} : #{$!}"
    ensure
      @pid = nil
    end
  end

  def capture_data(output)
    public_ip_prefix   = @public_ip_prefix
    private_ip_prefix  = @private_ip_prefix
    floating_ip_prefix = @floating_ip_prefix
    instance_id_prefix = @instance_id_prefix

    output.each do |line|
      # capture public ip from stardard output
      if line.index(public_ip_prefix)
        public_ip = line.split(":")[1].strip
        notify_observers(:public_ip, public_ip)
      end

      # capture private ip from stardard output
      if line.index(private_ip_prefix)
        private_ip = line.split(":")[1].strip
        notify_observers(:private_ip, private_ip)
      end
        
      # capture floating ip from stardard output
      if line.index(floating_ip_prefix)
        floating_ip = line.split(":")[1].strip
        notify_observers(:floating_ip, floating_ip)
      end

      # capture instance id from stardard output
      if line.index(instance_id_prefix)
        instance_id = line.split(":")[1].strip
        notify_observers(:instance_id, instance_id)
      end

      # capture vpn client ip
      capture = /vpn_server => (.+), vpnip => (.+)/.match(line)
      if capture
        vpn_client_ip = {:vpn_server => capture[1].strip, :vpnip => capture[2].strip}
        notify_observers(:vpn_client_ip, vpn_client_ip)
      end
    end
  end

  def add_observer(observer)
    @observers << observer
  end

  def notify_observers(key, value)
    @observers.each do |observer|
      observer.on_data(key, value)
    end
  end
end


class BaseCommandBuilder

  def initialize(node_name, node_info, services = [])
    @node_name = node_name
    @node_info = node_info
    @services = services
  end

  def build_create_command
    identity_file =  @node_info["identity_file"]
    ssh_user =  @node_info["ssh_user"]
    password =  @node_info["password"]
    port =  @node_info["port"]
    timeout = Float(@node_info["timeout"] || "0")
    cloud =  @node_info["cloud"] || Rails.application.config.notcloud

    command = ""
    command += "-x #{ssh_user} "
    command += "-N #{@node_name} "
    command += "-i #{identity_file} " if identity_file
    command += "-P #{password} " if password
    command += "-p #{port} " if port
    command += "--no-host-key-verify "

    command += "-r '"
    if @services.size > 0
      command += @services.map{|s| "recipe[NestedQEMU::#{s}]"}.join(",")
    else
      command += "recipe[NestedQEMU::common]"
    end
    command += "' "

    command
  end
end


class EC2CommandBuilder < BaseCommandBuilder
  def build_create_command
    security_groups =  @node_info["security_groups"] || "quicklaunch-1"
    image =  @node_info["image_id"]
    instance_type =  @node_info["instance_type"]
    key_pair_id =  @node_info["key_pair_id"]
    zone =  @node_info["availability_zone"]
    region = @node_info["region"]

    command = "knife ec2 server create "
    command += "-I #{image} "
    command += "-f #{instance_type} " if instance_type
    command += "-S #{key_pair_id} " if key_pair_id
    command += "-G #{security_groups} " if security_groups
    command += "-Z #{zone} " if zone
    command += "--region #{region}" if region
    command += build_auth_info

    command += super()
    command
  end

  def build_delete_command(instance_id)
    command = "knife ec2 server delete #{instance_id} -y "
    command += "-N #{@node_name} "
    command += build_auth_info
  end

  def build_auth_info
    access_key_id = @node_info["aws_access_key_id"]
    secret_access_key = @node_info["aws_secret_access_key"]
    if access_key_id.nil? || secret_access_key.nil?
      raise ParametersValidationError.new(:message => "EC2 auth info missing")
    end

    command = "-A #{access_key_id} "
    command += "-K #{secret_access_key} "
    command
  end
end


class OpenStackCommandBuilder < BaseCommandBuilder
  def build_create_command
    image_id =  @node_info["image_id"]
    instance_type =  @node_info["instance_type"]
    key_pair_id =  @node_info["key_pair_id"]

    command = "knife openstack server create "
    command += "-a "
    command += "-I #{image_id} "
    command += "-f #{instance_type} " if instance_type
    command += "-S #{key_pair_id} "
    command += build_auth_info

    command += super()
    command
  end

  def build_delete_command(instance_id)
    command = "knife openstack server delete #{instance_id} -y "
    command += "-N #{@node_name} "
    command += build_auth_info
  end

  def build_auth_info
    username = @node_info["openstack_username"]
    password = @node_info["openstack_password"]
    tenant   = @node_info["openstack_tenant"]
    endpoint = @node_info["openstack_endpoint"]
    if [username, password, tenant, endpoint].any?{|v| v.nil?}
      raise ParametersValidationError.new(:message => "openstack auth info missing")
    end

    command = "-A #{username} "
    command += "-K #{password} "
    command += "-T #{tenant} "
    command += "--openstack-api-endpoint #{endpoint} "
    command
  end
end


class BootstrapCommandBuilder < BaseCommandBuilder

  def initialize(node_name, node_info, services, server_ip)
    super(node_name, node_info, services)
    @server_ip = server_ip
  end

  def build_create_command
    command = "knife bootstrap "
    command += "#{@server_ip} "
    command += "--sudo "
    command += super()
    command
  end
end