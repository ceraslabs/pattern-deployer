xml.response do
  xml.status "success"
  xml << render("templates", :templates => @templates).gsub(/^/, "  ")
  xml.links do
    xml.link topology_path(@topology, :only_path => false), "resource" => "parent"
    xml.link topology_templates_path(@topology, :only_path => false), "resource" => "self"
    @templates.each do |template|
      xml.link topology_template_path(@topology, template, :only_path => false), "resource" => template.template_id
    end
  end
end
