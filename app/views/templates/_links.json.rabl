attribute :template_id => :resource_name
node(:resource_type){ |template| template.class.name }
node(:link){ |template| topology_template_path @topology, template, :only_path => false }
node(:sub_resources) do |template|
  template.services.map do |service|
    partial "services/links", :object => service
  end
end
