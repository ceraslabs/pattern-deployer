services.each do |service|
  xml << render("services/service", :service => service)
end