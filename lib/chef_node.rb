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

  def delete_key(key)
    @node.delete(key)
  end

  def save
    @node.save
  end

  def start_deployment
    %w{ is_success is_failed exception formatted_exception backtrace }.each do |key|
      self.delete_key(key) if self.has_key?(key)
    end
    self.save
  end

  def deployment_show_up?
    self.has_key?("is_success")
  end

  def deployment_failed?
    self.has_key?("is_failed") && self["is_failed"]
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
    if self["formatted_exception"]
      msg = self["formatted_exception"]
      if self["backtrace"]
        msg += "\nTrace: "
        msg += self["backtrace"][0..10].join("\n")
        msg += "\n............"
      end
    end

    msg
  end

  def reload
    Chef::Config.from_file(Rails.configuration.chef_config_file)
    Shef::Extensions.extend_context_object(self)
    @node = nodes.search("name:#{@node_name}").first
    raise "Cannot reload node #{@node_name}, since the node doesn't exist" if @node.nil?
  end

  def delete
    #chef_node = nodes.search("name:#{@node_name}").first
    #chef_node.destroy if chef_node
    @node.destroy
    @node = nil
  end

end

class ChefNodesManager

  def load_nodes_list
    @list_of_nodes = Chef::Node.list.keys
    @cache.each_key do |name|
      @cache.delete(name) unless @list_of_nodes.include?(name)
    end
  end

  def initialize
    Chef::Config.from_file(Rails.configuration.chef_config_file)
    Shef::Extensions.extend_context_object(self)

    @cache = Hash.new
    load_nodes_list
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
      @cache[node_name] = chef_node_wrapper
    end

    return @cache[node_name]
  end

  def delete(node_name)
    return if not @list_of_nodes.include?(node_name)

    begin
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
    rescue Exception => ex
      puts "INFO: an exception when deleting chef node #{node_name}"
      puts "[#{Time.now}] #{ex.class.name}: #{ex.message}"
      puts "Trace:"
      puts ex.backtrace.join("\n")
    end
  end

  #def deregister(node_name)
  #  @list_of_nodes.delete(node_name)
  #end

  def reload
    load_nodes_list
  end

  private_class_method :new
end