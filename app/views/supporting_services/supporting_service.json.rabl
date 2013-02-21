attributes :name, :id
attribute :available? => :available
attribute :get_status => :deploymentStatus
attribute :get_error => :deploymentError
attribute :get_msg => :deploymentMessage
node :link do |ss|
  supporting_service_path ss, :only_path => false
end