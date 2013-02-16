attribute :credential_id => :resource_name
node :resource_type do |credential|
  credential.class.name
end
node :link do |credential|
  credential_path(credential, :only_path => false)
end