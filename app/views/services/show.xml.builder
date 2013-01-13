xml.response do
  xml.status "success"
  xml << render("service", :service => @service).gsub(/^/, "  ")
  xml.links do
    if @template
      xml.link topology_template_services_path(@topology, @template, :only_path => false), "resource" => "parent"
      xml.link topology_template_service_path(@topology, @template, @service, :only_path => false), "resource" => "self"
    elsif @container
      xml.link topology_container_node_services_path(@topology, @container, @node, :only_path => false), "resource" => "parent"
      xml.link topology_container_node_service_path(@topology, @container, @node, @service, :only_path => false), "resource" => "self"
    else
      xml.link topology_node_services_path(@topology, @node, :only_path => false), "resource" => "parent"
      xml.link topology_node_service_path(@topology, @node, @service, :only_path => false), "resource" => "self"
    end
  end
end