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
require "chef/shef/ext"

class DatabagWrapper

  def initialize(name, manager, data = Hash.new)
    @name = name
    @manager = manager
    @data = data
    @data["id"] = name
  end

  def get_name
    return @name
  end

  def [](key)
    key = key.to_s if key.class == Symbol
    return @data[key]
  end

  def []=(key, value)
    key = key.to_s if key.class == Symbol
    @data[key] = value
  end

  def has_key?(key)
    key = key.to_s if key.class == Symbol
    return @data.has_key?(key)
  end

  def delete_key(key)
    key = key.to_s if key.class == Symbol
    @data.delete(key)
  end

  def reset_data(data = Hash.new)
    @data = data
    @data["id"] = @name
    save
  end

  def delete
    databag = Chef::DataBag.new
    databag.name(@name)
    databag.destroy
    @data = nil
    @manager.deregister_databag(self)
  end

  def save
    databag_item = nil
    if @manager.databag_exist?(@name)
      databag_item = data_bag_item(@name, @name)
    else
      databag = Chef::DataBag.new
      databag.name(@name)
      databag.save
      databag_item = Chef::DataBagItem.new
      databag_item.data_bag(@name)
    end

    databag_item.raw_data = @data
    databag_item.save

    @manager.register_databag(self)
  end

  def get_server_ip
    databag["server_ip"]
  end
end

class DatabagsManager

  def sync_cache
    @list_of_databags = Chef::DataBag.list.keys
  end

  alias :reload :sync_cache

  def initialize
    Chef::Config.from_file(Rails.configuration.chef_config_file)
    Shef::Extensions.extend_context_object(self)

    sync_cache
    @cache = Hash.new
  end

  @@instance = new

  def self.instance
    return @@instance
  end

  def databag_exist?(name)
    @list_of_databags.any? do |databag|
      databag == name
    end
  end

  def get_or_create_databag(name)
    databag = get_databag(name)
    if databag.nil?
      databag = create_databag(name)
      databag.save
    end

    databag
  end

  def create_databag(name)
    if databag_exist?(name)
      raise "Cannot create databag #{name} since the name has been taken"
    end

    databag = DatabagWrapper.new(name, self)
    Shef::Extensions.extend_context_object(databag)
    @cache[name] = databag

    databag
  end

  def reset_databag(name, data = Hash.new)
    databag = get_databag(name)
    if databag.nil?
      raise "Cannot reset databag #{name} since it doesnot exist"
    end

    databag.reset_data(data)
  end

  def register_databag(databag)
    @list_of_databags << databag.get_name unless @list_of_databags.include?(databag.get_name)
  end

  def deregister_databag(databag)
    @list_of_databags.delete(databag.get_name)
  end

  def get_databag(name)
    return nil unless databag_exist?(name)

    unless @cache.has_key?(name)
      data = data_bag_item(name, name).raw_data
      databag = DatabagWrapper.new(name, self, data)
      Shef::Extensions.extend_context_object(databag)
      @cache[name] = databag
    end

    return @cache[name]
  end

  def get_server_ip(name)
    databag = get_databag(name)
    if databag
      return databag.get_server_ip
    else
      return nil
    end
  end


  private_class_method :new

end