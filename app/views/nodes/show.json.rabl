object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :node do
  partial "nodes/node", :object => @node
end
node :links do
  partial "nodes/links", :object => @node
end