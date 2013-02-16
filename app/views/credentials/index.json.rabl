object false
node :status do
  "success"
end
node :credentials do
  @credentials.map do |credential|
    partial "credentials/credential", :object => credential
  end
end
node :links do
  partial "credentials/links", :object => @credentials
end
