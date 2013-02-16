object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :container do
  partial "containers/container", :object => @container
end
node :links do
  partial "containers/links", :object => @container
end