xml.credential do
  xml.credential_id credential.credential_id
  xml.for_cloud credential.for_cloud
  xml.aws_access_key_id credential.aws_access_key_id if credential.aws_access_key_id
  xml.openstack_username credential.openstack_username if credential.openstack_username
  xml.openstack_tenant credential.openstack_tenant if credential.openstack_tenant
  xml.openstack_endpoint credential.openstack_endpoint if credential.openstack_endpoint
end