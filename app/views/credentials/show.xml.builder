xml.response do
  xml.status "success"
  xml << render("credentials/credential", :credential => @credential).gsub(/^/, "  ")
  xml.links do
    xml.link credentials_path(:only_path => false), "resource" => "parent"
    xml.link credential_path(@credential, :only_path => false), "resource" => "self"
  end
end