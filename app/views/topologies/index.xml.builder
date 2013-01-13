xml.response do
  xml.status "success"
  xml << render("topologies", :topologies => @topologies).gsub(/^/, "  ") if @topologies.size > 0
  xml.links do
    xml.link api_root_path(:only_path => false), "resource" => "parent"
    xml.link topologies_path(:only_path => false), "resource" => "self"
    @topologies.each do |topology|
      xml.link topology_path(topology, :only_path => false), "resource" => topology.topology_id
    end
  end
end