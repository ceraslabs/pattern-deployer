attribute :node_id => :resource_name
node(:resource_type){ |node| node.class.name }
node(:link) do |node|
  parent = node.parent
  if parent.class == Container
    topology_container_node_path @topology, parent, node, :only_path => false
  else
    topology_node_path @topology, node, :only_path => false
  end
end
node(:sub_resources) do |node|
  node.services.map do |service|
    partial "services/links", :object => service
  end
end