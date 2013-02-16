object false
node :status do
  "success"
end
node :uploaded_files do
  @files.map do |file|
    partial "uploaded_files/uploaded_file", :object => file
  end
end
node :links do
  partial "uploaded_files/links", :object => @files
end