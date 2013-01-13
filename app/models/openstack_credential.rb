class OpenstackCredential < Credential

  alias_attribute :username, :openstack_username
  alias_attribute :password, :openstack_password
  alias_attribute :tenant, :openstack_tenant
  alias_attribute :endpoint, :openstack_endpoint

  attr_accessible :openstack_username, :openstack_password, :openstack_tenant, :openstack_endpoint
  attr_accessible :username, :password, :tenant, :endpoint

  validates :openstack_username, :presence => true
  validates :openstack_password, :presence => true
  validates :openstack_tenant, :presence => true
  validates :openstack_endpoint, :presence => true
end
