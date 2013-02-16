attribute :service_id => :resource_name
node(:resource_type){ |service| service.class.name }
node(:link) do |service|
  parent = service.service_container
  if parent.class == Template
    topology_template_service_path @topology, parent, service, :only_path => false
  elsif parent.class == Node
    grandparent = parent.parent
    if grandparent.class == Container
      topology_container_node_service_path @topology, grandparent, parent, service, :only_path => false
    elsif grandparent.class == Topology
      topology_node_service_path @topology, parent, service, :only_path => false
    end
  end
end
node(:sub_resources){ Array.new }