xml.response do
  xml.status "success"
  xml.deployment_status @topology.get_deployment_status
  xml.deployment_error @topology.get_error if @topology.get_error
  xml.message @topology.get_msg if @topology.get_msg

  xml.deployment_info do
    @topology.get_deployed_nodes.each do |node|
      xml.node(:name => node.get_name_without_suffix) do
        xml.status node.get_deployment_status
        xml.server_ip node.get_server_ip if node.get_server_ip
        xml.error node.get_err_msg unless node.get_err_msg.blank?
        node.get_services_info.each do |service_name, infos|
          infos.each do |info|
            xml.service(:name => service_name) do
              info.each do |key, value|
                xml.tag!(key, value)
              end
            end
          end
        end
      end
    end
  end

  xml << render("topology", :topology => @topology).gsub(/^/, "  ")

  xml.links do
    xml.link topologies_path(:only_path => false), "resource" => "parent"
    xml.link topology_path(@topology, :only_path => false), "resource" => "self"
    xml.link topology_containers_path(@topology, :only_path => false), "resource" => "containers"
    xml.link topology_nodes_path(@topology, :only_path => false), "resource" => "nodes"
    xml.link topology_templates_path(@topology, :only_path => false), "resource" => "templates"
  end
end