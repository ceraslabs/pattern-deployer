attribute :name => :resource_name
node :resource_type do |ss|
  ss.class.name
end
node :link do |ss|
  supporting_service_path(ss, :only_path => false)
end