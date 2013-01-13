nodes.each do |node|
  xml << render("nodes/node", :node => node)
end
