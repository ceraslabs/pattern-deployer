xml.uploaded_files do
  files.each do |file|
    xml << render("uploaded_files/uploaded_file", :file => file).gsub(/^/, "  ")
  end
end