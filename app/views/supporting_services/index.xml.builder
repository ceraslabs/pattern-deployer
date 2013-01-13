xml.response do
  xml.status "success"
  xml << render("supporting_services", :services => @services).gsub(/^/, "  ") if @services.size > 0
  xml.links do
    xml.link api_root_path(:only_path => false), "resource" => "parent"
    xml.link supporting_services_path(:only_path => false), "resource" => "self"
    @services.each do |service|
      xml.link supporting_service_path(service, :only_path => false), "resource" => service.name
    end
  end
end