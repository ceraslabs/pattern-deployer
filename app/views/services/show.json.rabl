object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :service do
  partial "services/service", :object => @service
end
node :links do
  partial "services/links", :object => @service
end