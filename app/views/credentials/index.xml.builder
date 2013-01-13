xml.response do
  xml.status "success"
  xml << render("credentials/credentials", :credentials => @credentials).gsub(/^/, "  ")
  xml.links do
    xml.link api_root_path(:only_path => false), "resource" => "parent"
    xml.link credentials_path(:only_path => false), "resource" => "self"
    @credentials.each do |credential|
      xml.link credential_path(credential, :only_path => false), "resource" => credential.credential_id
    end
  end
end