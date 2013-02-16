object false
node :status do
  "success"
end
node :credential do
  partial "credentials/credential", :object => @credential
end
credentials = [@credential]
node :links do
  partial "credentials/links", :object => credentials
end