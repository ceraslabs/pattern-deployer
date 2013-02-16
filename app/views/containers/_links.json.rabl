attribute :container_id => :resource_name
node(:resource_type){ |container| container.class.name }
node(:link){ |container| topology_container_path @topology, container, :only_path => false }
node(:sub_resources) do |container|
  container.nodes.map do |node|
    partial "nodes/links", :object => node
  end
end