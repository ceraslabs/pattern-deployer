node :status do
  "success"
end
node :links do
  links = partial "topologies/links", :object => @topologies
  links += partial "credentials/links", :object => @credentials
  links += partial "uploaded_files/links", :object => @uploaded_files
  links += partial "supporting_services/links", :object => @supporting_services
  links
end