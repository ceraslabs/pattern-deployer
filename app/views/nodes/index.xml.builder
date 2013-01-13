xml.response do
  xml.status "success"

  xml.nodes do
    @nodes.each do |node|
      xml << render("nodes/node", :node => node).gsub(/^/, "  ")
    end
  end

 xml.links do
    if @container
      xml.link topology_container_path(@topology, @container, :only_path => false),
               "resource" => "parent"
      xml.link topology_container_nodes_path(@topology, @container, :only_path => false),
               "resource" => "self"
    else
      xml.link topology_path(@topology, :only_path => false),
               "resource" => "parent"
      xml.link topology_nodes_path(@topology, :only_path => false),
               "resource" => "self"
    end

    @nodes.each do |node|
      if @container
        xml.link topology_container_node_path(@topology, @container, node, :only_path => false),
                 "resource" => node.node_id
      else
        xml.link topology_node_path(@topology, node, :only_path => false),
                 "resource" => node.node_id
      end
    end
  end
end