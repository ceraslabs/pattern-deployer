object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :nodes do
  @nodes.map do |node|
    partial "nodes/node", :object => node
  end
end
node :links do
  @nodes.map do |node|
    partial "nodes/links", :object => node
  end
end