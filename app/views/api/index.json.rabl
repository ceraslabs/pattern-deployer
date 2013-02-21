child :links do
  node :topologies do
    topologies_path(:only_path => false)
  end
  node :credentials do
    credentials_path(:only_path => false)
  end
  node :uploaded_files do
    uploaded_files_path(:only_path => false)
  end
  node :supporting_services do
    supporting_services_path(:only_path => false)
  end
end