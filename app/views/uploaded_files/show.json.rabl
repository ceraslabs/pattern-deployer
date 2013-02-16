object false
node :status do
  "success"
end
node :uploaded_file do
  partial "uploaded_files/uploaded_file", :object => @file
end
files = [@file]
node :links do
  partial "uploaded_files/links", :object => files
end