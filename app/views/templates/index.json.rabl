object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :templates do
  @templates.map do |template|
    partial "templates/template", :object => template
  end
end
node :links do
  @templates.map do |template|
    partial "templates/links", :object => template
  end
end