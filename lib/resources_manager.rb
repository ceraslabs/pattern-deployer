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
module Resource
  CREDENTIAL = "credential"
  KEY_PAIR = "identity_file"
  WAR_FILE = "war_file"
  SQL_SCRIPT = "sql_script_file"
end

module FileType
  IDENTITY_FILE = Resource::KEY_PAIR
  WAR_FILE = Resource::WAR_FILE
  SQL_SCRIPT_FILE = Resource::SQL_SCRIPT
end


class ResourceWrapper

  def initialize(resource, type, context)
    @resource = resource
    @type = type
    @context = context
    @selected = false
  end

  def resource_type
    @type
  end

  def get_id
    @resource[:id]
  end

  def select
    @selected = true
  end

  def selected?
    @selected
  end

  def owned_by_me?
    @resource.owner.id == get_current_user.id
  end

  def readable_by_me?
    resource = @resource
    @context.instance_eval{ can? :read, resource }
  end

  def get_current_user
    @context.instance_eval{ current_user }
  end

  def respond_to?(sym)
    @resource.respond_to?(sym) || super(sym)
  end

  def method_missing(sym, *args, &block)
    if @resource.respond_to?(sym)
      return @resource.send(sym, *args, &block)
    else
      super(sym, *args, &block)
    end
  end
end

class ResourcesManager

  attr_reader :topology

  @@file_types = [Resource::KEY_PAIR, Resource::WAR_FILE, Resource::SQL_SCRIPT]

  def initialize(topology, controller)
    @topology = topology
    @context = controller
    @resources = Array.new
  end

  def add_resources(resources, type)
    resources.each do |res|
      @resources << ResourceWrapper.new(res, type, @context) unless self.include?(res, type)
    end
  end

  def find_ec2_credential
    find_credential(Rails.application.config.ec2)
  end

  def find_openstack_credential
    find_credential(Rails.application.config.openstack)
  end

  def find_credential_by_id(id)
    @resources.find do |res|
      res.resource_type == Resource::CREDENTIAL && res.get_id == id
    end
  end

  def find_credential_by_name(credential_name, cloud)
    credentials = @resources.select do |res|
      res.resource_type == Resource::CREDENTIAL && res.credential_id == credential_name && cloud.casecmp(res.for_cloud) == 0
    end
    credential = select_resource(credentials)
    credential
  end

  def find_keypair_id(cloud)
    keypairs = @resources.select do |res|
      res.resource_type == Resource::KEY_PAIR && cloud.casecmp(res.for_cloud) == 0
    end
    keypair = select_resource(keypairs)
    keypair ? keypair.key_pair_id : nil
  end

  def find_file_by_id(id)
    @resources.find{ |res| @@file_types.include?(res.resource_type) && res.get_id == id }
  end

  def find_identity_file(key_pair_id)
    id_files = @resources.select do |res|
      res.resource_type == Resource::KEY_PAIR && res.key_pair_id == key_pair_id
    end
    id_file = select_resource(id_files)
    id_file
  end

  def find_file_by_name(file_name)
    files = @resources.select do |res|
      @@file_types.include?(res.resource_type) && res.file_name == file_name
    end
    file = select_resource(files)
    file
  end

  def each(&block)
    @resources.each(&block)
  end

  protected

  def include?(resource, type)
    @resources.any? do |my_resource|
      my_resource.resource_type == type && my_resource.get_id == resource[:id]
    end
  end

  def find_credential(cloud)
    credentials = @resources.select do |res|
      res.resource_type == Resource::CREDENTIAL && cloud.casecmp(res.for_cloud) == 0
    end
    credential = select_resource(credentials)
    credential
  end

  def select_resource(resources)
    resource = resources.find{ |res| res.owner.id == self.topology.owner.id && res.readable_by_me? }
    resource = resources.find{ |res| res.owned_by_me? } if resource.nil?
    resource = resources.find{ |res| res.readable_by_me? } if resource.nil?
    resource
  end

  #def get_file_path(file_name)
  #  file_types = [FileType::IDENTITY_FILE, FileType::WAR_FILE, FileType::SQL_SCRIPT_FILE]
  #  file_types.each do |type|
  #    get_resources(type).each do |file|
  #      return file.file_path if file.file_name == file_name
  #    end
  #  end

  #  return nil
  #end

  #def get_resources(type)
  #  resources = Array.new
  #  @resources.each do |resource|
  #    if type == resource.get_type
  #      resources << resource.get_resource
  #    end
  #  end

  #  resources
  #end
end