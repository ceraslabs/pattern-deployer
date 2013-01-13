xml.topologies do
  topologies.each do |topology|
    xml.topology(:id => topology.topology_id) do
      xml.description topology.description if topology.description && !topology.description.empty?
      xml.deployment_state topology.get_deployment_status
      #xml.message topology.get_msg if topology.get_msg
      #error = topology.get_error
      #xml.error error if error && !error.empty?
    end
  end
end