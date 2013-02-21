attribute :id
attribute :credential_id => :name
attribute :for_cloud => :forCloud
attribute :aws_access_key_id => :awsAccessKeyId
attribute :openstack_username => :openstackUsername
attribute :openstack_tenant => :openstackTenant
attribute :openstack_endpoint => :openstackEndpoint
node :link do |credential|
  credential_path credential, :only_path => false
end
