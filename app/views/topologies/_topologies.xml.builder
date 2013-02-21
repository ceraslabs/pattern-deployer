xml.topologies do
  topologies.each do |topology|
    xml << render("topologies/topology", :topology => topology)
  end
end