xml.supporting_services do
  services.each do |service|
    xml << render("supporting_services/supporting_service", :service => service).gsub(/^/, "  ")
  end
end