attribute :id
attribute :service_id => :name
node :pattern do |service|
  get_service_pattern @pattern, service
end
node :link do |service|
  parent = service.service_container
  if parent.class == Template
    topology_template_service_path service.topology, parent, service, :only_path => false
  elsif parent.class == Node
    grandparent = parent.parent
    if grandparent.class == Container
      topology_container_node_service_path service.topology, grandparent, parent, service, :only_path => false
    elsif grandparent.class == Topology
      topology_node_service_path service.topology, parent, service, :only_path => false
    end
  end
end