xml.response do
  xml.status "success"
  xml.links do
    xml.link api_root_path(:only_path => false), "resource" => "self"
    xml.link topologies_path(:only_path => false), "resource" => "topologies"
    xml.link credentials_path(:only_path => false), "resource" => "credentials"
    xml.link uploaded_files_path(:only_path => false), "resource" => "uploaded_files"
    xml.link supporting_services_path(:only_path => false), "resource" => "supporting_services"
  end
end