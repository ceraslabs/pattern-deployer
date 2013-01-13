xml.response do
  xml.status "success"
  xml.services do
    @services.each do |service|
      xml << render("services/service", :service => service).gsub(/^/, " ")
    end
  end
  xml.links do
    if @template
      xml.link topology_template_path(@topology, @template, :only_path => false), "resource" => "parent"
      xml.link topology_template_services_path(@topology, @template, :only_path => false), "resource" => "self"
    else
      if @container
        xml.link topology_container_node_path(@topology, @container, @node, :only_path => false), "resource" => "parent"
        xml.link topology_container_node_services_path(@topology, @container, @node, :only_path => false), "resource" => "self"
      else
        xml.link topology_node_path(@topology, @node, :only_path => false), "resource" => "parent"
        xml.link topology_node_services_path(@topology, @node, :only_path => false), "resource" => "self"
      end
    end
    @services.each do |service|
      if @template
        service_link = topology_template_service_path(@topology, @template, service, :only_path => false)
      else
        if @container
          service_link = topology_container_node_service_path(@topology, @container, @node, service, :only_path => false)
        else
          service_link = topology_node_service_path(@topology, @node, service, :only_path => false)
        end
      end
      xml.link service_link, "resource" => service.service_id
    end
  end
end
