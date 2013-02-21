container = root_object

attribute :id
attribute :num_of_copies => :numOfCopies
attribute :container_id => :name
node :pattern do
  get_container_pattern @pattern, container
end
node :link do
  topology_container_path container.topology, container, :only_path => false
end
child container.nodes => :nodes do
  extends "nodes/node"
end
