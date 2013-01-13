xml.container("id" => container.container_id, "num_of_copies" => container.num_of_copies) do
  xml << render("nodes/nodes", :nodes => container.nodes).gsub(/^/, "  ") if container.nodes.size > 0
end