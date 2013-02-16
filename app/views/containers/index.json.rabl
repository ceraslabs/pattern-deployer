object false
node(:status){ "success" }
node(:pattern){ @pattern }
node(:containers) do
  @containers.map do |container|
    partial "containers/container", :object => container
  end
end
node(:links) do
  @containers.map do |container|
    partial "containers/links", :object => container
  end
end