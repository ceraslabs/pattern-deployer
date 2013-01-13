xml.topology("id" => topology.topology_id) do
  xml.description topology.description if topology.description && !topology.description.empty?
  xml << render("templates/templates", :templates => topology.templates).gsub(/^/, "  ") if topology.templates.size > 0
  xml << render("containers/containers", :containers => topology.containers).gsub(/^/, "  ") if topology.containers.size > 0
  xml << render("nodes/nodes", :nodes => topology.nodes).gsub(/^/, "  ") if topology.nodes.size > 0
end