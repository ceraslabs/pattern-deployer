xml.response do
  xml.status "success"
  xml << render("container", :container => @container).gsub(/^/, "  ")
  xml.links do
    xml.link topology_containers_path(@topology, :only_path => false), "resource" => "parent"
    xml.link topology_container_path(@topology, @container, :only_path => false), "resource" => "self"
    xml.link topology_container_nodes_path(@topology, @container, :only_path => false), "resource" => "nodes"
  end
end
