xml.credentials do
  credentials.each do |credential|
    xml << render("credentials/credential", :credential => credential).gsub(/^/, "  ")
  end
end