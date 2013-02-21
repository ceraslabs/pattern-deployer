attribute :node_id => :name
attribute :id
node :link do |node|
  parent = node.parent
  if parent.class == Container
    topology_container_node_path node.topology, parent, node, :only_path => false
  else
    topology_node_path node.topology, node, :only_path => false
  end
end
node :pattern do |node|
  get_node_pattern @pattern, node
end
child root_object.services => :services do
  extends "services/service"
end