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

  def initialize(resource, type, is_mine)
    @resource = resource
    @type = type
    @is_mine = is_mine
  end

  def resource_type
    @type
  end

  def mine?
    @is_mine
  end

  def get_id
    @resource[:id]
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

  def initialize
    @resources = Array.new
  end

  def add_resources_if_not_added(resources, type, options={})
    is_mine = options[:is_mine] || false
    resources.each do |res|
      @resources << ResourceWrapper.new(res, type, is_mine) unless self.include?(res, type)
    end
  end

  def find_my_ec2_credential
    find_my_credential(Rails.application.config.ec2)
  end

  def find_my_openstack_credential
    find_my_credential(Rails.application.config.openstack)
  end

  def find_credential_by_id(credential_id)
    @resources.select do |res|
      res.resource_type == Resource::CREDENTIAL && res.credential_id == credential_id
    end.first
  end

  def find_my_key_pair(cloud)
    @resources.find do |res|
      res.resource_type == Resource::KEY_PAIR && res.for_cloud == cloud && res.mine?
    end
  end

  def find_identity_file(key_pair_id)
    @resources.find do |res|
      res.resource_type == Resource::KEY_PAIR && res.key_pair_id == key_pair_id
    end
  end

  #def find_key_pair(cloud, key_pair_id)
  #  @resources.select do |res|
  #    res.resource_type == Resource::KEY_PAIR && res.for_cloud == cloud && res.key_pair_id == key_pair_id && res.mine?
  #  end.first
  #end

  def get_file(file_name, file_type)
    @resources.find do |res|
      res.resource_type == file_type && res.file_name == file_name && res.mine?
    end
  end

  protected

  def include?(resource, type)
    @resources.any? do |my_resource|
      my_resource.resource_type == type && my_resource.get_id == resource[:id]
    end
  end

  def find_my_credential(cloud)
    @resources.find do |res|
      res.resource_type == Resource::CREDENTIAL && res.for_cloud == cloud && res.mine?
    end
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