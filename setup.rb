#!/usr/bin/ruby
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

require 'fileutils'
require 'ipaddr'
require 'rubygems'
require 'yaml'

# a list of exit code
SETUP_OK = 0
SUBCOMMAND_MISSING = 1
SUBCOMMAND_INVALID = 2
OPTIONS_INVALID = 3
INVALID_CWD = 4
SETUP_ERROR = 10


module ShellUtils
  def execute_and_exit_on_fail(command, options={})
    tmp_file = "/tmp/pd_error.txt"
    command = "su #{options[:as_user]} -c '#{command}'" if options[:as_user] && options[:as_user] != ENV['USER']
    output = `#{command} 2>#{tmp_file}`.strip
    unless $?.success?
      puts "ERROR: failed to execute command #{command}"
      puts "STDOUT:"
      puts output
      puts "STDERR:"
      puts `cat #{tmp_file}`
      exit SETUP_ERROR
    end
    output
  end
end

include ShellUtils

%w{ excon mixlib-cli json ohai }.each do |gem|
  command = "gem install #{gem} --no-ri --no-rdoc --conservative"
  execute_and_exit_on_fail(command)
end

Gem.clear_paths
require 'excon'
require 'json'
require 'mixlib/cli'
require 'ohai'


class SubCommand

  include ShellUtils

  def initialize(cli, env)
    @cli = cli
    @env = env
  end

  def run
    # install bundler
    puts "Installing Bundler..."
    install_bundler
    puts "Bundler is installed"

    # run "bundle install" to install depending gems
    puts "Installing depending Gems..."
    run_bundle_install
    puts "Depending Gems are installed"

    # setup the database for this app to use
    puts "Setting up the database..."
    setup_db
    puts "Database is setup"

    # clean up previuos assets in case of any
    puts "Cleaning up previous compiled assets..."
    clean_assets
    puts "Assets are cleaned up"

    # precompile assets
    puts "Pre-compiling assets..."
    precompile_assets if self.respond_to?(:precompile_assets)
    puts "Assets are pre-compiled"

    # generate secret token
    puts "Generating a secret token..."
    generate_secret_token
    puts "Secret token is generated"

    # setup Chef for this app to use
    puts "Setting up Chef..."
    setup_chef
    puts "Chef is setup"

    # genereate API documentations
    puts "Generating API docs..."
    generate_docs
    puts "API docs are generated"

    # print instruction to start the app
    print_success_msg if self.respond_to?(:print_success_msg)
  end


  protected

  def install_bundler
    execute_and_exit_on_fail("gem install bundler --no-ri --no-rdoc")
  end

  def create_or_update_db_config_file
    db_file = "config/database.yml"

    if File.exists?(db_file)
      db_config = YAML.load_file(db_file)
    else
      db_config = Hash.new
    end

    db_config[@env] ||= Hash.new
    db_config[@env]["adapter"] = "mysql2"
    db_config[@env]["username"] = @cli.config[:database_username]
    db_config[@env]["password"] = @cli.config[:database_password]
    db_config[@env]["host"] = @cli.config[:database_host]
    db_config[@env]["database"] = @cli.config[:database_name]

    write_to_file(db_file) do |fout|
      fout.write(db_config.to_yaml)
    end
  end

  def create_db_if_not_before
    command = "bundle exec rake db:create RAILS_ENV=#{@env}"
    execute_and_exit_on_fail(command, :as_user => @cli.config[:as_user])
  end

  def migrate_db
    command = "bundle exec rake db:migrate RAILS_ENV=#{@env}"
    execute_and_exit_on_fail(command, :as_user => @cli.config[:as_user])
  end

  def generate_secret_token
    secret_token_file = "config/initializers/secret_token.rb"
    unless File.exists?(secret_token_file)
      secret_token = execute_and_exit_on_fail("bundle exec rake secret", :as_user => @cli.config[:as_user])
      write_to_file(secret_token_file) do |fout|
        fout.print "PatternDeployer::Application.config.secret_token = '#{secret_token}'"
      end
    end
  end

  def clean_assets
    command = "bundle exec rake assets:clean"
    execute_and_exit_on_fail(command, :as_user => @cli.config[:as_user])
  end

  def setup_chef
    config_file = create_chef_config_file
    upload_cookbooks(config_file)
  end

  def create_chef_config_file
    user_home = execute_and_exit_on_fail("echo ~", :as_user => @cli.config[:as_user])
    config_file = [user_home, ".chef", "knife.rb"].join("/")
    write_to_file(config_file) do |fout|
      fout.puts <<-EOH
log_level               :info
log_location            STDOUT
node_name               '#{@cli.config[:chef_client_name]}'
client_key              '#{@cli.config[:chef_client_key]}'
validation_client_name  'chef-validator'
validation_key          '#{@cli.config[:chef_validation_key]}'
chef_server_url         '#{@cli.config[:chef_server_url]}'
cache_type              'BasicFile'
cache_options( :path => '#{user_home}/.chef/checksums' )
EOH
    end

    # link knife.rb
    file_link = "chef-repo/.chef/knife.rb"
    FileUtils.rm_f(file_link)
    FileUtils.ln(config_file, file_link)
    FileUtils.chown(@cli.config[:as_user], nil, file_link)

    return config_file
  end

  def upload_cookbooks(chef_config_file)
    cookbooks_dir = "chef-repo/cookbooks"

    cookbooks_to_upload = Array.new
    Dir.foreach(cookbooks_dir) do |file|
      file_path = "#{cookbooks_dir}/#{file}"
      next if !File.directory?(file_path) || file == "." || file == ".."
      cookbooks_to_upload << file
    end

    progress = false
    while cookbooks_to_upload.size > 0
      cookbooks_to_upload.each do |cookbook|
        command = "bundle exec knife cookbook upload #{cookbook} -o #{cookbooks_dir} -c #{chef_config_file} 2>/dev/null"
        if system(command)
          progress = true
          cookbooks_to_upload.delete(cookbook)
        end
      end

      if progress
        progress = false
      else
        raise "failed to upload cookbooks #{cookbooks_to_upload.join(", ")}"
      end
    end
  end

  def generate_docs
    # generate api docs from comment
    docs_dir = "app/views/api_docs"
    FileUtils.mkdir_p(docs_dir)
    command = "bundle exec source2swagger -i app/controllers -e rb -c \"##~\" -o #{docs_dir} >/dev/null"
    execute_and_exit_on_fail(command, :as_user => @cli.config[:as_user])

    # add .erb suffix to file names
    Dir.new(docs_dir).each do |file_name|
      next unless file_name.match(/\.json$/)

      new_file_name = file_name.sub(/\.json$/, ".json.erb")
      Dir.chdir(docs_dir) do
        json = nil
        File.open(file_name, "r") do |fin|
          json = fin.read
        end
        write_to_file(new_file_name) do |fout|
          fout.write(sort_json(JSON.parse(json), 0))
        end
        FileUtils.rm(file_name)
      end
    end

    # collect the list of APIs
    apis_names = Array.new
    Dir.foreach(docs_dir) do |file_name|
      next if file_name == "." || file_name == ".." || file_name == "index.json.erb"
      api_name = file_name.sub(/\.json.erb$/, "")
      apis_names << api_name
    end
    apis_names.sort!

    apis = Array.new
    apis_names.each do |api_name|
      apis << %Q[{"path":"/api_docs/#{api_name}", "description":"#{api_name}"}]
    end

    json = <<-EOL
{
  "apiVersion":"0.2",
  "swaggerVersion":"1.1",
  "basePath":"<%= request.protocol + request.host_with_port %>",
  "apis":[
    #{apis.join(",\n")}
  ]
}
EOL

    write_to_file("app/views/api_docs/index.json.erb") do |out|
      out.write(sort_json(JSON.parse(json), 0))
    end
  end

  def sort_json(json_obj, level)
    str = "{\n"
    str += json_obj.sort.map do |key, value|
      padding(level + 1) + %Q["#{key}": #{json_value_to_string(value, level + 1)}]
    end.join(",\n")
    str += "\n"
    str += padding(level) + "}"
    str
  end

  def json_value_to_string(value, level)
    if value.class == Fixnum || value.class == TrueClass || value.class == FalseClass
      return value.to_s
    elsif value.class == String
      return %Q["#{value}"]
    elsif value.class == Array
      value = sort_if_all_str(value)
      str = "[\n"
      str += value.map do |item|
        padding(level + 1) + json_value_to_string(item, level + 1)
      end.join(",\n")
      str += "\n"
      str += padding(level) + "]"
      return str
    elsif value.class == Hash
      return sort_json(value, level)
    elsif value.class == NilClass
      return "null"
    else
      raise "json value '#{value}' is of invalid type '#{value.class.to_s}'"
    end
  end

  def sort_if_all_str(array)
    all_str = array.all?{|item| item.class == String}
    array.sort! if all_str
    array
  end

  def padding(level)
    (1..level).map{|c| "  "}.join
  end

  def write_to_file(file_path, &block)
    File.open(file_path, "w", &block)
    FileUtils.chown(@cli.config[:as_user] || ENV['USER'], nil, file_path)
  end

end

class ProductionCommand < SubCommand

  include Mixlib::CLI
  include ShellUtils

  banner "ruby #{__FILE__} production (options)"

  def initialize(cli)
    super(cli, "production")
  end

  protected

  def run_bundle_install
    gem_lock_file = "Gemfile.lock"
    FileUtils.rm(gem_lock_file) if File.exists?(gem_lock_file)

    chef_repo = "chef-repo"
    FileUtils.rm(chef_repo) if File.exists?(chef_repo)

    execute_and_exit_on_fail("bundle install --path=vendor/bundle", :as_user => @cli.config[:as_user])
  end

  def setup_db
    create_or_update_db_config_file
    create_db_if_not_before
    migrate_db
  end

  def precompile_assets
    command = "bundle exec rake assets:precompile"
    execute_and_exit_on_fail(command, :as_user => @cli.config[:as_user])
  end

  def print_success_msg
    puts "Congratulations! The application is ready to start"
    puts
    puts "* To start the application, please type following:"
    puts "cd #{FileUtils.pwd}"
    puts "sudo bundle exec passenger start -p 80 -e production -d --user=#{@cli.config[:as_user]} --max-pool-size=3 --min-instances=3"
    puts
    puts "* To stop the application:"
    puts "cd #{FileUtils.pwd}"
    puts "sudo bundle exec passenger stop -p 80"
    puts
  end

end

class DevelopCommand < SubCommand

  include Mixlib::CLI
  include ShellUtils

  banner "ruby #{__FILE__} development (options)"

  def initialize(cli)
    super(cli, "development")
  end

  protected

  def run_bundle_install
    execute_and_exit_on_fail("bundle install --system")
  end

  def setup_db
    create_or_update_db_config_file
    create_db_if_not_before
    migrate_db
  end

  def print_success_msg
    puts "Congratulations! The application is ready to start"
    puts
    puts "* To start the application, please type following:"
    puts "cd #{FileUtils.pwd}"
    puts "sudo rails server"
    puts
  end

end

class TestCommand < SubCommand

  include Mixlib::CLI
  include ShellUtils

  banner "ruby #{__FILE__} test (options)"

  def initialize(cli)
    super(cli, "test")
  end

  protected

  def run_bundle_install
    execute_and_exit_on_fail("bundle install --system")
  end

  def setup_db
    create_or_update_db_config_file
    create_db_if_not_before
    migrate_db
  end

end

class SetupCLI

  include Mixlib::CLI

  NO_COMMAND_GIVEN   = "You need to pass a sub-command (e.g., ruby #{__FILE__} SUB-COMMAND)\n"
  INVALID_SUBCOMMAND = "You need to pass a valid sub-command (e.g., ruby #{__FILE__} SUB-COMMAND)\n"

  banner "Usage: ruby #{__FILE__} subcommand (options)"

  option :help,
    :short        => "-h",
    :long         => "--help",
    :description  => "Show this message",
    :on           => :tail,
    :boolean      => true

  option :use_defaults,
    :short        => "-d",
    :long         => "--defaults",
    :description  => "Use defaults value for all questions(do not prompt)",
    :boolean      => true

  option :database_username,
    :short        => "-u USER",
    :long         => "--db-user USER",
    :description  => "The database username",
    :default      => "pattern-deployer"

  option :database_password,
    :short        => "-p PWD",
    :long         => "--db-password PWD",
    :description  => "The database password",
    :default      => "pattern-deployer"

  option :database_host,
    :long         => "--db-host HOST",
    :description  => "The host of database",
    :default      => "localhost"

  option :database_name,
    :short        => "-n NAME",
    :long         => "--db-name NAME",
    :description  => "The name of database",
    :default      => "pattern-deployer"

  option :chef_server_url,
    :short        => "-s URL",
    :long         => "--chef-server URL",
    :description  => "Chef server URL",
    :default      => begin
      retried = false
      failed = false

      begin
        query_url ||= "http://169.254.169.254/latest/meta-data/public-ipv4"
        my_ip = Excon.get(query_url, :connect_timeout => 5).body
        IPAddr.new(my_ip)
      rescue ArgumentError, Excon::Errors::Timeout
        if not retried
          retried = true
          query_url = "http://ifconfig.me/ip"
          retry
        else
          failed = true
        end
      end

      if failed
        ohai = Ohai::System.new
        ohai.all_plugins
        my_ip = ohai[:ipaddress]
      end

      "http://#{my_ip.strip}:4000"
    end

  option :chef_client_key,
    :short        => "-k PATH",
    :long         => "--chef-client-key PATH",
    :description  => "Chef API client key",
    :default      => File.expand_path("~") + "/.chef/workstation.pem",
    :proc         => Proc.new { |path| File.expand_path(path) }

  option :chef_client_name,
    :long         => "--chef-client-name NAME",
    :description  => "Chef API client name",
    :default      => "workstation"

  option :chef_validation_key,
    :short        => "-v PATH",
    :long         => "--chef-validation-key PATH",
    :description  => "Chef validation key",
    :default      => File.expand_path("~") + "/.chef/validation.pem",
    :proc         => Proc.new { |path| File.expand_path(path) }

  option :as_user,
    :long         => "--as-user USER",
    :description  => "Setup the app for USER",
    :default      => ENV['USER']


  def run(args)
    validate_and_parse_options

    begin
      self.parse_options
    rescue OptionParser::InvalidOption => e
      puts "ERROR: #{e}\n"
      exit INVALID_OPTIONS
    end

    ask_user_for_config
    subcommand = get_subcommand(args[0])
    subcommand.run

    exit SETUP_OK
  end


  private

  def ask_user_for_config
    unless config[:use_defaults]
      config[:as_user]             = ask_question("Please enter the owner of the installed application: ", :default => config[:as_user])
      config[:database_username]   = ask_question("Please enter the username to login the database: ", :default => config[:database_username])
      config[:database_password]   = ask_question("Please enter the password of the database's user: ", :default => config[:database_password])
      config[:database_host]       = ask_question("Please enter the host of the database: ", :default => config[:database_host])
      config[:database_name]       = ask_question("Please enter the name of database used for this app: ", :default => config[:database_name])
      config[:chef_server_url]     = ask_question("Please enter the chef server URL: ", :default => config[:chef_server_url])
      config[:chef_client_name]    = ask_question("Please enter a Chef clientname: ", :default => config[:chef_client_name])
      config[:chef_client_key]     = ask_question("Please enter the location of the Chef client key: ", :default => config[:chef_client_key])
      config[:chef_validation_key] = ask_question("Please enter the location of the Chef validation key: ", :default => config[:chef_validation_key])
    end
  end

  def ask_question(question, opts={})
    question = question + "[#{opts[:default]}] " if opts[:default]
    print question
    answer = $stdin.readline.strip
    if answer && !answer.empty?
      return answer
    else
      return opts[:default]
    end
  end

  def get_subcommands
    @subcommands ||= {:production => ProductionCommand.new(self), :development => DevelopCommand.new(self), :test => TestCommand.new(self)}
    @subcommands
  end

  def get_subcommand(name)
    name = name.to_sym if name.class == String
    subcommands = get_subcommands
    subcommands[name]
  end

  def validate_and_parse_options
    if no_command_given?
      print_help_and_exit(SUBCOMMAND_MISSING, NO_COMMAND_GIVEN)
    elsif no_subcommand_given?
      if want_help?
        print_help_and_exit
      else
        print_help_and_exit(SUBCOMMAND_MISSING, NO_COMMAND_GIVEN)
      end
    elsif !subcommand_valid?
      print_help_and_exit(SUBCOMMAND_INVALID, INVALID_SUBCOMMAND)
    end
  end

  def no_subcommand_given?
    ARGV[0] =~ /^-/
  end

  def no_command_given?
    ARGV.empty?
  end

  def subcommand_valid?
    get_subcommands.has_key?(ARGV[0].to_sym)
  end

  def want_help?
    ARGV[0] =~ /^(--help|-h)$/
  end

  def print_help_and_exit(exitcode=SETUP_OK, fatal_message=nil)
    puts "ERROR: #{fatal_message}\n" if fatal_message

    begin
      self.parse_options
    rescue OptionParser::InvalidOption => e
      puts "#{e}\n"
    end
    puts self.opt_parser
    puts
    puts "Available subcommands: (for details, ruby #{__FILE__} SUB-COMMAND --help)\n\n"
    get_subcommands.each do |name, command|
      puts command.banner
    end
    puts

    exit exitcode
  end

end


if FileUtils.pwd != File.expand_path(File.dirname(__FILE__))
  puts "ERROR: this script must be execute under the same directory. Please 'cd' to '#{File.expand_path(File.dirname(__FILE__))}' first."
  exit INVALID_CWD
end

SetupCLI.new.run(ARGV)
