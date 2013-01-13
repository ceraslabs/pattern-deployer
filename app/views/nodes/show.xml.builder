xml.response do
  xml.status "success"
  xml << render("node", :node => @node).gsub(/^/, "  ")
  xml.links do
    if @container
      xml.link topology_container_nodes_path(@topology, @container, :only_path => false),
               "resource" => "parent"
      xml.link topology_container_node_path(@topology, @container, @node, :only_path => false),
               "resource" => "self"
      xml.link topology_container_node_services_path(@topology, @container, @node, :only_path => false),
               "resource" => "services"
    else
      xml.link topology_nodes_path(@topology, :only_path => false),
               "resource" => "parent"
      xml.link topology_node_path(@topology, @node, :only_path => false),
               "resource" => "self"
      xml.link topology_node_services_path(@topology, @node, :only_path => false),
               "resource" => "services"
    end
  end
end