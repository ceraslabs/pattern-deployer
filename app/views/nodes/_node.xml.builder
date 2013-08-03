xml.node("id" => node.node_id) do
  node.templates.each do |template|
    xml.use_template(:name => template.template_id)
  end

  xml << render("services/services", :services => node.services).gsub(/^/, "  ") if node.services.size > 0

  xml.nest_within(:node => node.container_node.node_id) if node.container_node

  node.attrs.each do |key, value|
    if value.class == Hash
      xml.tag!(key) do
        value.each do |nested_key, nested_value|
          xml.tag!(nested_key, nested_value)
        end
      end
    else
      xml.tag!(key, value.to_s)
    end
  end
end