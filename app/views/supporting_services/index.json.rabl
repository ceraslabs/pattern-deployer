object false
node :status do
  "success"
end
node :supporting_services do
  @supporting_services.map do |ss|
    partial "supporting_services/supporting_service", :object => ss
  end
end
node :links do
  partial "supporting_services/links", :object => @supporting_services
end