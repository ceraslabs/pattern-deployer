xml.instance_templates do
  templates.each do |template|
    xml << render("templates/template", :template => template).gsub(/^/, "  ")
  end
end