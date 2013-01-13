xml.service("name" => service.service_id) do
  service.service_to_node_refs.each do |node_ref|
    xml.tag!(node_ref.ref_name, "node" => node_ref.node.node_id)
  end

  service.properties.each do |property|
    xml << property.gsub(/^/, "  ")
  end

  xml << "\n" if service.properties.size > 0
end