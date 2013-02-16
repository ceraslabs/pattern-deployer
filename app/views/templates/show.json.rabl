object false
node(:status){ "success" }
node(:pattern){ @pattern }
node :template do
  partial "templates/template", :object => @template
end
node :links do
  partial "templates/links", :object => @template
end