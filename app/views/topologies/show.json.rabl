object false
node :status do
  "success"
end
child @topology => :topology do
  attributes :id, :description
  attribute :topology_id => :name
end
child(:deployment) do
  node :status do
    @topology.get_deployment_status
  end
  node :error do
    @topology.get_error
  end
  node :message do
    @topology.get_msg
  end
  child(@topology.get_deployed_nodes(@pattern) => :nodes) do
    node(:status) do |node|
      node.get_update_state == State::UNDEPLOY ? node.get_deploy_state : node.get_update_state
    end
    node(:server_ip) do |node|
      node.get_server_ip
    end
    node(:services) do |node|
      node.get_services
    end
  end
  applications = @topology.get_deployed_nodes(@pattern).select{ |node| node.application_server? }
  child(applications => :applications) do
    node(:name){ |node| node.get_app_name }
    node(:url){ |node| node.get_app_url }
    node(:in_node){ |node| node.get_pretty_name }
  end
  databases = @topology.get_deployed_nodes(@pattern).select{ |node| node.database_server? }
  child(databases => :databases) do
    node(:system){ |node| node.get_db_system }
    node(:host){ |node| node.get_server_ip }
    node(:user){ |node| node.get_db_user }
    node(:password){ |node| node.get_db_pwd }
    node(:root_password){ |node| node.get_db_root_pwd }
    node(:in_node){ |node| node.get_pretty_name }
  end
end
node(:pattern){ @pattern }
child(@topology => :links) do
  attribute :topology_id => :resource_name
  node(:resource_type){ |topology| topology.class.name }
  node(:link){ |topology| topology_path topology, :only_path => false }
  node(:sub_resources) do |topology|
    links = topology.nodes.map do |node|
      partial "nodes/links", :object => node
    end
    links += topology.containers.map do |container|
      partial "containers/links", :object => container
    end
    links += topology.templates.map do |template|
      partial "templates/links", :object => template
    end
    links
  end
end