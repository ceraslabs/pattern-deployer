xml.response do
  xml.status "success"
  xml << render("supporting_service", :service => @service).gsub(/^/, "  ")
  xml.links do
    xml.link supporting_services_path(:only_path => false), "resource" => "parent"
    xml.link supporting_service_path(@service, :only_path => false), "resource" => "self"
  end
end