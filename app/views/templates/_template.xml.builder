xml.template("id" => template.template_id) do
  template.base_templates.each do |base_template|
    xml.extend(:template => base_template.template_id)
  end

  xml << render("services/services", :services => template.services).gsub(/^/, "  ") if template.services.size > 0

  template.attrs.each do |key, value|
    if value.class == Hash
      xml.tag!(key) do
        value.each do |nested_key, nested_value|
          xml.tag!(nested_key, nested_value)
        end
      end
    else
      xml.tag!(key, value.to_s)
    end
  end
end