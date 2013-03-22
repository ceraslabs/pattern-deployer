xml.node("id" => node.node_id) do
  node.templates.each do |template|
    xml.use_template(:name => template.template_id)
  end

  xml << render("services/services", :services => node.services).gsub(/^/, "  ") if node.services.size > 0

  if node.container_node
    xml.nest_within(:node => node.container_node.node_id) do
      node.nested_nodes_info.each do |info|
        xml << info.gsub(/^/, "  ")
      end
    end
  end

  node.attrs.each do |key, value|
    xml.tag!(key, value)
  end
end