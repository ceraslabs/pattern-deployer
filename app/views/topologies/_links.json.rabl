attribute :topology_id => :resource_name
node :resource_type do |topology|
  topology.class.name
end
node :link do |topology|
  topology_path(topology, :only_path => false)
end
