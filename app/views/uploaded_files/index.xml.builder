xml.response do
  xml.status "success"
  xml << render("uploaded_files/uploaded_files", :files => @files).gsub(/^/, "  ") if @files.size > 0
  xml.links do
    xml.link api_root_path(:only_path => false), "resource" => "parent"
    xml.link uploaded_files_path(:only_path => false), "resource" => "self"
    @files.each do |file|
      xml.link uploaded_file_path(file, :only_path => false), "resource" => file.file_name
    end
  end
end