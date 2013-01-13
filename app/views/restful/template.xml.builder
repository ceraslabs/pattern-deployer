xml.response do
  xml.status "success"
  xml << render("topologies/topologies").gsub(/^/, "  ")
end
