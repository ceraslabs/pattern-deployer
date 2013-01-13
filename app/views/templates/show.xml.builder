xml.response do
  xml.status "success"
  xml << render("template", :template => @template).gsub(/^/, "  ")
  xml.links do
    xml.link topology_templates_path(@topology, :only_path => false), "resource" => "parent"
    xml.link topology_template_path(@topology, @template, :only_path => false), "resource" => "self"
  end
end