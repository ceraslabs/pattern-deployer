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
require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module PatternDeployer
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.exceptions_app = self.routes


    #####################################################
    #                                                   #
    # custom configuration                              #
    #                                                   #
    #####################################################

    # The location of chef repository
    config.chef_repo_dir = "#{Rails.root}/chef-repo"

    # link chef-repo to the installed gem
    unless File.exists?(config.chef_repo_dir)
      FileUtils.ln_s Gem.loaded_specs["customized-chef-repo"].full_gem_path.strip, config.chef_repo_dir
    end

    # Amazon EC2
    config.ec2 = "ec2"

    # Openstack
    config.openstack = "openstack"

    # The deployment is not on any cloud
    config.cloud_unspecified = "unspecified"

    # The cloud provider this application support
    config.supported_clouds = [config.ec2, config.openstack]

    # The supported node service this application support.
    # Each node service corresponse to a set of scripts that will run to config the node on deployment
    #config.supported_node_services = ["openvpn_server", "openvpn_client", "database_server", "web_balancer", "web_server",
    #                                  "snort_prepost", "snort", "front_end_balancer", "ossec_client", "virsh", 
    #                                  "dns_client", "chef_server", "self_install"]

    # The path to the schema file that will be used to validate the application topology
    config.schema_file = [Rails.root, "lib", "NestedQEMU-schema.xsd"].join("/")

    # The location of the bootstrap template file
    config.bootstrap_templates_dir = [config.chef_repo_dir, ".chef", "bootstrap"].join("/")

    # The location of chef config file
    config.chef_config_file = "#{Rails.root}/chef-repo/.chef/knife.rb"

    # The name of the cookbook
    config.chef_cookbook_name = "NestedQEMU"

    # The deployment of application pattern will stop if the deployment time is more than this.
    config.chef_max_deploy_time = 3600

    # The timeout for waiting ip address of another deploying instance
    config.chef_wait_ip_timeout = 300

    # The timeout for waiting the virtual ip address of another deploying instance
    config.chef_wait_vpnip_timeout = 600

    # The timeout for waiting members of load balancer
    config.chef_wait_balancer_members_timeout = 1800

    # Auto allocate floating IP when creating servers in OpenStack
    config.openstack_auto_allocate_ip = true

    # Auto deallocate floating IP when shuting down servers in OpenStack
    config.openstack_auto_deallocate_ip = true

    # Get the IP address of current server
    require 'excon'
    require 'ipaddr'
    require 'ohai'
    begin
      query_url ||= "http://169.254.169.254/latest/meta-data/public-ipv4"
      public_ip = Excon.get(query_url, :connect_timeout => 5).body
      config.public_ip = IPAddr.new(public_ip).to_s
    rescue ArgumentError, Excon::Errors::Timeout
      # nothing
    end

    begin
      query_url = "http://169.254.169.254/latest/meta-data/private-ipv4"
      private_ip = Excon.get(query_url, :connect_timeout => 5).body
      config.private_ip = IPAddr.new(private_ip).to_s
    rescue ArgumentError, Excon::Errors::Timeout
      # Get IP address by using Ohai.
      ohai = Ohai::System.new
      ohai.all_plugins
      config.private_ip = ohai[:ipaddress]
    end

    # A list of nodes definition. Node declared here can be reference without declared in pattern.
    config.nodes = Array.new
    if config.respond_to?(:public_ip)
      config.nodes << "<node id='PDS'>
                         <is_external>true</is_external>
                         <server_ip>#{config.public_ip}</server_ip>
                       </node>"
    end
    if config.respond_to?(:private_ip)
      config.nodes << "<node id='PDSPrivate'>
                         <is_external>true</is_external>
                         <server_ip>#{config.private_ip}</server_ip>
                       </node>"
    end

    # A place holder.
    config.host = ""

  end
end