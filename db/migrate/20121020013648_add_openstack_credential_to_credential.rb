class AddOpenstackCredentialToCredential < ActiveRecord::Migration
  def up
    add_column :credentials, :openstack_username, :string
    add_column :credentials, :openstack_password, :string
    add_column :credentials, :openstack_tenant, :string
    add_column :credentials, :openstack_endpoint, :string
  end

  def down
    drop_column :credentials, :openstack_username
    drop_column :credentials, :openstack_password
    drop_column :credentials, :openstack_tenant
    drop_column :credentials, :openstack_endpoint
  end
end
