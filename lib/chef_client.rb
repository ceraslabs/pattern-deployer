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
require "chef/knife"
require "chef/knife/client_delete"
require "chef/shef/ext"


class ChefClientsManager

  def initialize
    Chef::Config.from_file(Rails.configuration.chef_config_file)
    Shef::Extensions.extend_context_object(self)

    @list_of_clients = load_clients_list
  end

  def load_clients_list
    Chef::ApiClient.list.keys
  end

  @@instance = new

  def self.instance
    return @@instance
  end

  def delete(client_name)
    return if not @list_of_clients.include?(client_name)

    delete_client = Chef::Knife::ClientDelete.new
    delete_client.name_args = [client_name]
    delete_client.config[:yes] = true
    delete_client.run
  rescue Net::HTTPServerException => e
    self.reload
    #debug
    puts "[#{Time.now}]INFO: Failed to delete chef client #{client_name}: #{e.message}"
    puts e.backtrace[0..20].join("\n")
  ensure
    @list_of_clients.delete(client_name)
  end

  #def deregister(client_name)
  #  @list_of_clients.delete(client_name)
  #end

  def reload
    @list_of_clients = load_clients_list
  end

  private_class_method :new
end