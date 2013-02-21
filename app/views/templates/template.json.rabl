template = root_object

attribute :id
attribute :template_id => :name
node :link do
  topology_template_path template.topology, template, :only_path => false
end
node :pattern do
  get_template_pattern @pattern, template
end
child template.services => :services do
  extends "services/service"
end