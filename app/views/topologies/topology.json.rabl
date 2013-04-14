topology = root_object
topology_pattern = get_topology_pattern(@pattern, topology)

attributes :id, :description
attribute :topology_id => :name
child topology => :deployment do
  node :status do
    topology.get_deployment_status
  end
  node :error do
    topology.get_error
  end
  node :message do
    topology.get_msg
  end
  nodes = topology.get_deployed_nodes(topology_pattern)
  child(nodes => :servers) do
    attributes :name, :services, :status
    attribute :server_ip => :serverIp
  end
  applications = nodes.select{ |node| node.is_app_server }
  child(applications => :applications) do
    attribute :app_name => :name
    attribute :app_url => :url
    attribute :name => :inServer
  end
  databases = nodes.select{ |node| node.is_db_server }
  child(databases => :databases) do
    attribute :db_system => :system
    attribute :server_ip => :host
    attribute :db_user => :user
    attribute :db_pwd => :password
    attribute :db_root_pwd => :rootPassword
    attribute :name => :inServer
  end
  monitoring_servers = nodes.select{ |node| node.is_monitoring_server }
  child(monitoring_servers => :monitoring_servers) do
    attribute :monitoring_server_url => :url
    attribute :name => :inServer
  end
end
node :pattern do
  topology_pattern
end
node :link do
  topology_path topology, :only_path => false
end
child topology.nodes => :nodes do
  extends "nodes/node"
end
child topology.containers => :containers do
  extends "containers/container"
end
child topology.templates => :templates do
  extends "templates/template"
end
