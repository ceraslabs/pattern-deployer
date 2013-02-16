object false
node :status do
  "success"
end
node :links do
  partial "topologies/links", :object => @topologies
end