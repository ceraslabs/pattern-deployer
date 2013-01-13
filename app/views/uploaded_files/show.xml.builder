xml.response do
  xml.status "success"
  xml << render("uploaded_files/uploaded_file", :file => @file).gsub(/^/, "  ")
  xml.links do
    xml.link uploaded_files_path(:only_path => false), "resource" => "parent"
    xml.link uploaded_file_path(@file, :only_path => false), "resource" => "self"
  end
end