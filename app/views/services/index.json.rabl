object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :services do
  @services.map do |service|
    partial "services/service", :object => service
  end
end
node :links do
  @services.map do |service|
    partial "services/links", :object => service
  end
end