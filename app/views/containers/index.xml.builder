xml.response do
  xml.status "success"
  xml.containers do
    @containers.each do |container|
      xml << render("containers/container", :container => container).gsub(/^/, "  ")
    end
  end
  xml.links do
    xml.link topology_path(@topology, :only_path => false), "resource" => "parent"
    xml.link topology_containers_path(@topology, :only_path => false), "resource" => "self"
    @containers.each do |container|
      xml.link topology_container_path(@topology, container, :only_path => false), "resource" => container.container_id
    end
  end
end
