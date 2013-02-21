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
  child(topology.get_deployed_nodes(topology_pattern) => :servers) do
    attribute :get_pretty_name => :name
    attribute :get_server_ip => :serverIp
    attribute :get_services => :services
    node(:status) do |node|
      node.get_update_state == State::UNDEPLOY ? node.get_deploy_state : node.get_update_state
    end
  end
  applications = topology.get_deployed_nodes(topology_pattern).select{ |node| node.application_server? }
  child(applications => :applications) do
    node(:name){ |node| node.get_app_name }
    node(:url){ |node| node.get_app_url }
    node(:inServer){ |node| node.get_pretty_name }
  end
  databases = topology.get_deployed_nodes(topology_pattern).select{ |node| node.database_server? }
  child(databases => :databases) do
    node(:system){ |node| node.get_db_system }
    node(:host){ |node| node.get_server_ip }
    node(:user){ |node| node.get_db_user }
    node(:password){ |node| node.get_db_pwd }
    node(:rootPassword){ |node| node.get_db_root_pwd }
    node(:inServer){ |node| node.get_pretty_name }
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
