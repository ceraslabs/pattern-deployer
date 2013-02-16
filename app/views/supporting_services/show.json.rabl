object false
node :status do
  "success"
end
node :supporting_service do
  partial "supporting_services/supporting_service", :object => @supporting_service
end
supporting_services = [@supporting_service]
node :links do
  partial "supporting_services/links", :object => supporting_services
end