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
require "chef/knife/node_delete"
require "chef/shef/ext"
require "weakref"

class ChefNodeWrapper
  def initialize(node_name, node)
    @node_name = node_name
    @node = node
  end

  def get_name
    return @node_name
  end

  def [](key)
    return @node[key]
  end

  #def []=(key, value)
  #  @node[key] = value
  #end

  def has_key?(key)
    @node.has_key?(key)
  end

  def get_server_ip
    if self.has_key?("ec2")
      return self["ec2"]["public_ipv4"]  
    elsif self.has_key?("ipaddress")
      return self["ipaddress"]
    else
      raise "ipaddress is missing in chef node #{@node_name}"
    end
  end

  def get_private_ip
    if self.has_key?("ec2")
      return self["ec2"]["public_ipv4"]
    elsif self.has_key?("ipaddress")
      return self["ipaddress"]
    else
      raise "ipaddress is missing in chef node #{@node_name}"
    end
  end

  def get_err_msg
    if self.has_key?("formatted_exception")
      msg = self["formatted_exception"]
      if self.has_key?("backtrace")
        msg += "\nTrace: "
        msg += self["backtrace"][0..10].join("\n")
        msg += "\n............"
      end
    end

    msg
  end

  #def reload
  #  chef_node = nodes.search("name:#{@node_name}").first
  #  @node = chef_node if chef_node
  #end

  def delete
    #chef_node = nodes.search("name:#{@node_name}").first
    #chef_node.destroy if chef_node
    @node.destroy
    @node = nil
  end
end

class ChefNodesManager

  def initialize
    Chef::Config.from_file(Rails.configuration.chef_config_file)
    Shef::Extensions.extend_context_object(self)

    @list_of_nodes = load_nodes_list
    @cache = Hash.new
  end

  def load_nodes_list
    Chef::Node.list.keys
  end

  @@instance = new

  def self.instance
    return @@instance
  end

  #def create_node(node_name)
  #  return nil if get_node(node_name)

  #  chef_node_wrapper = ChefNodeWrapper.new(node_name)
  #  Shef::Extensions.extend_context_object(chef_node_wrapper)
  #  chef_node_wrapper
  #end

  def get_node(node_name)
    if !@cache.has_key?(node_name) || !@cache[node_name].weakref_alive?
      chef_node = nodes.search("name:#{node_name}").first
      return nil unless chef_node

      chef_node_wrapper = ChefNodeWrapper.new(node_name, chef_node)
      chef_node_wrapper = WeakRef.new(chef_node_wrapper)
      #Shef::Extensions.extend_context_object(chef_node_wrapper)
      @cache[node_name] = chef_node_wrapper
    end

    return @cache[node_name]
  end

  def delete(node_name)
    if @list_of_nodes.include?(node_name)
      if @cache.has_key?(node_name)
        # This delete chef node and cleanup the cache, but it may talk to chef server twice
        chef_node = get_node(node_name)
        if chef_node.nil?
          raise "Node '#{node_name}' doesnot exist, so it cannot be deleted"
        end

        chef_node.delete
        @cache.delete(node_name)
      else
        # This delete the node without cleaning the cache, and it talk to chef server just once
        node_delete = Chef::Knife::NodeDelete.new
        node_delete.name_args = [node_name]
        node_delete.config[:yes] = true
        node_delete.run
      end

      @list_of_nodes.delete(node_name)
    end
  end

  #def deregister(node_name)
  #  @list_of_nodes.delete(node_name)
  #end

  def reload
    @list_of_nodes = load_nodes_list
  end

  private_class_method :new
end